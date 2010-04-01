package Hailo::Engine::Default;

use 5.010;
use Any::Moose;
use Any::Moose 'X::Types::'.any_moose() => [qw< Int >];
use List::Util qw<min first shuffle>;
use List::MoreUtils qw<uniq>;

with qw[ Hailo::Role::Arguments Hailo::Role::Engine ];

has repeat_limit => (
    isa     => Int,
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $order = $self->order;
        return min(($order * 10), 50);
    }
);

sub BUILD {
    my ($self) = @_;

    # This performance hack is here because in our tight loops calling
    # $self->storage->sth->{...} is actually a significant part of the
    # overall program execution time since we're doing two method
    # calls and hash dereferences for each call to the database.

    my $sth = $self->storage->sth;
    while (my ($k, $v) = each %$sth) {
        $self->{"_sth_$k"} = $v;
    }

    return;
}

## no critic (Subroutines::ProhibitExcessComplexity)
sub reply {
    my $self = shift;
    my $tokens = shift // [];

    # we will favor these tokens when making the reply
    my @key_tokens = @$tokens;

    # shuffle the tokens and discard half of them
    @key_tokens = do {
        my $i = 0;
        grep { $i++ % 2 == 0 } shuffle(@key_tokens);
    };

    my (@key_ids, %token_cache);
    for my $token_info (@key_tokens) {
        my $text = $token_info->[1];
        my $info = $self->_token_similar($text);
        next unless defined $info;
        my ($id, $spacing) = @$info;
        next unless defined $id;
        push @key_ids, $id;
        next if exists $token_cache{$id};
        $token_cache{$id} = [$spacing, $text];
    }

    # sort the rest by rareness
    @key_ids = $self->_find_rare_tokens(\@key_ids, 2);

    # get the middle expression
    my $seed_token_id = shift @key_ids;
    my ($orig_expr_id, @token_ids) = $self->_random_expr($seed_token_id);
    return unless defined $orig_expr_id; # we don't know any expressions yet

    # remove key tokens we're already using
    @key_ids = grep { my $used = $_; !first { $_ == $used } @token_ids } @key_ids;

    my $expr_id = $orig_expr_id;

    # construct the end of the reply
    $self->_construct_reply('next', $expr_id, \@token_ids, \@key_ids);

    # construct the beginning of the reply
    $self->_construct_reply('prev', $expr_id, \@token_ids, \@key_ids);

    # translate token ids to token spacing/text
    my @reply = map {
        $token_cache{$_} // ($token_cache{$_} = $self->_token_info($_))
    } @token_ids;
    return \@reply;
}

sub _token_info {
    my ($self, $id) = @_;

    $self->{_sth_token_info}->execute($id);
    my @res = $self->{_sth_token_info}->fetchrow_array;
    return \@res;
}

sub learn {
    my ($self, $tokens) = @_;
    my $order = $self->order;

    # only learn from inputs which are long enough
    return if @$tokens < $order;

    my %token_cache;

    for my $token (@$tokens) {
        my $key = join '', @$token;
        next if exists $token_cache{$key};
        $token_cache{$key} = $self->_token_id_add($token);
    }

    # process every expression of length $order
    for my $i (0 .. @$tokens - $order) {
        my @expr = map { $token_cache{ join('', @{ $tokens->[$_] }) } } $i .. $i+$order-1;
        my $expr_id = $self->_expr_id(\@expr);

        if (!defined $expr_id) {
            $expr_id = $self->_add_expr(\@expr);
            $self->{_sth_inc_token_count}->execute($_) for uniq(@expr);
        }

        # add link to next token for this expression, if any
        if ($i < @$tokens - $order) {
            my $next_id = $token_cache{ join('', @{ $tokens->[$i+$order] }) };
            $self->_inc_link('next_token', $expr_id, $next_id);
        }

        # add link to previous token for this expression, if any
        if ($i > 0) {
            my $prev_id = $token_cache{ join('', @{ $tokens->[$i-1] }) };
            $self->_inc_link('prev_token', $expr_id, $prev_id);
        }

        # add links to boundary token if appropriate
        my $b = $self->storage->_boundary_token_id;
        $self->_inc_link('prev_token', $expr_id, $b) if $i == 0;
        $self->_inc_link('next_token', $expr_id, $b) if $i == @$tokens-$order;
    }

    return;
}

# sort token ids based on how rare they are
sub _find_rare_tokens {
    my ($self, $token_ids, $min) = @_;
    return unless @$token_ids;

    my %links;
    for my $id (@$token_ids) {
        next if exists $links{$id};
        $self->{_sth_token_count}->execute($id);
        $links{$id} = $self->{_sth_token_count}->fetchrow_array;
    }

    # remove tokens which are too rare
    my @ids = grep { $links{$_} >= $min } @$token_ids;

    @ids = sort { $links{$a} <=> $links{$b} } @ids;

    return @ids;
}

# increase the link weight between an expression and a token
sub _inc_link {
    my ($self, $type, $expr_id, $token_id) = @_;

    $self->{"_sth_${type}_count"}->execute($expr_id, $token_id);
    my $count = $self->{"_sth_${type}_count"}->fetchrow_array;

    if (defined $count) {
        $self->{"_sth_${type}_inc"}->execute($expr_id, $token_id);
    }
    else {
        $self->{"_sth_${type}_add"}->execute($expr_id, $token_id);
    }

    return;
}

# add new expression to the database
sub _add_expr {
    my ($self, $token_ids) = @_;

    # add the expression
    $self->{_sth_add_expr}->execute(@$token_ids);
    return $self->storage->dbh->last_insert_id(undef, undef, "expr", undef);
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $tokens) = @_;
    $self->{_sth_expr_id}->execute(@$tokens);
    return $self->{_sth_expr_id}->fetchrow_array();
}

# return token id if the token exists
sub _token_id {
    my ($self, $token_info) = @_;

    $self->{_sth_token_id}->execute(@$token_info);
    my $token_id = $self->{_sth_token_id}->fetchrow_array();

    return unless defined $token_id;
    return $token_id;
}

# get token id (adding the token if it doesn't exist)
sub _token_id_add {
    my ($self, $token_info) = @_;

    my $token_id = $self->_token_id($token_info);
    $token_id = $self->_add_token($token_info) unless defined $token_id;
    return $token_id;
}

# return all tokens (regardless of spacing) that consist of this text
sub _token_similar {
    my ($self, $token_text) = @_;
    $self->{_sth_token_similar}->execute($token_text);
    return $self->{_sth_token_similar}->fetchrow_arrayref;
}

# add a new token and return its id
sub _add_token {
    my ($self, $token_info) = @_;
    $self->{_sth_add_token}->execute(@$token_info);
    return $self->storage->dbh->last_insert_id(undef, undef, "token", undef);
}

# return a random expression containing the given token
sub _random_expr {
    my ($self, $token_id) = @_;

    my $expr;

    if (!defined $token_id) {
        $self->{_sth_random_expr}->execute();
        $expr = $self->{_sth_random_expr}->fetchrow_arrayref();
    }
    else {
        # try the positions in a random order
        for my $pos (shuffle 0 .. $self->order-1) {
            my $column = "token${pos}_id";

            # get a random expression which includes the token at this position
            $self->{"_sth_expr_by_$column"}->execute($token_id);
            $expr = $self->{"_sth_expr_by_$column"}->fetchrow_arrayref();
            last if defined $expr;
        }
    }

    return unless defined $expr;
    return @$expr;
}

# return a new next/previous token
sub _pos_token {
    my ($self, $pos, $expr_id, $key_tokens) = @_;

    $self->{"_sth_${pos}_token_get"}->execute($expr_id);
    my $pos_tokens = $self->{"_sth_${pos}_token_get"}->fetchall_arrayref();

    if (defined $key_tokens) {
        for my $i (0 .. $#{ $key_tokens }) {
            my $want_id = $key_tokens->[$i];
            my @ids     = map { $_->[0] } @$pos_tokens;
            my $has_id  = grep { $_ == $want_id } @ids;
            next unless $has_id;
            return splice @$key_tokens, $i, 1;
        }
    }

    my @novel_tokens;
    for my $token (@$pos_tokens) {
        push @novel_tokens, ($token->[0]) x $token->[1];
    }
    return $novel_tokens[rand @novel_tokens];
}

sub _construct_reply {
    my ($self, $what, $expr_id, $token_ids, $key_ids) = @_;
    my $order          = $self->order;
    my $repeat_limit   = $self->repeat_limit;
    my $boundary_token = $self->storage->_boundary_token_id;

    my $i = 0;
    while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit * 3) ||
             ($i >= $repeat_limit and uniq(@$token_ids) <= $order))) {
            last;
        }

        my $id = $self->_pos_token($what, $expr_id, $key_ids);
        last if $id eq $boundary_token;

        given ($what) {
            when ('next') {
                push @$token_ids, $id;
                $expr_id = $self->_expr_id([@$token_ids[-$order..-1]]);
            }
            when ('prev') {
                unshift @$token_ids, $id;
                $expr_id = $self->_expr_id([@$token_ids[0..$order-1]]);
            }
        }
    } continue {
        $i++;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Engine::Default - The default engine backend for L<Hailo|Hailo>

=head1 DESCRIPTION

This backend implements the logic of replying to and learning from
input using the resources given to the L<engine
roles|Hailo::Role::Engine>.

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
