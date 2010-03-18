package Hailo::Engine::Default;
use 5.010;
use Any::Moose;
use Any::Moose 'X::Types::'.any_moose() => [qw< Int >];
use List::Util qw<min first shuffle>;
use List::MoreUtils qw<uniq>;

with qw[ Hailo::Role::Arguments Hailo::Role::Engine ];

has storage => (
    required      => 1,
    is            => 'ro',
    documentation => "Our copy of the current Storage object",
);

has repeat_limit => (
    isa     => Int,
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $order = $self->storage->order;
        return min(($order * 10), 50);
    }
);

## no critic (Subroutines::ProhibitExcessComplexity)
sub reply {
    my $self = shift;
    my $tokens = shift // [];
    my $order = $self->storage->order;

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
        next if !defined $info;
        my ($id, $spacing) = @$info;
        next if !defined $id;
        push @key_ids, $id;
        next if exists $token_cache{$id};
        $token_cache{$id} = [$spacing, $text];
    }

    # sort the rest by rareness
    @key_ids = $self->_find_rare_tokens(\@key_ids, 2);

    # get the middle expression
    my $seed_token_id = shift @key_ids;
    my ($orig_expr_id, @token_ids) = $self->_random_expr($seed_token_id);
    return if !defined $orig_expr_id; # we don't know any expressions yet

    # remove key tokens we're already using
    @key_ids = grep { my $used = $_; !first { $_ == $used } @token_ids } @key_ids;

    my $repeat_limit = $self->repeat_limit;
    my $expr_id = $orig_expr_id;

    # construct the end of the reply
    my $i = 0;
    while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit * 3) ||
             ($i >= $repeat_limit and uniq(@token_ids) <= $order))) {
            last;
        }
        my $next_id = $self->_pos_token('next', $expr_id, \@key_ids);
        last if $next_id eq $self->storage->_boundary_token_id;
        push @token_ids, $next_id;
        $expr_id = $self->_expr_id([@token_ids[-$order..-1]]);
    } continue {
        $i++;
    }

    $expr_id = $orig_expr_id;

    # construct the beginning of the reply
    $i = 0; while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit * 3) ||
             ($i >= $repeat_limit and uniq(@token_ids) <= $order))) {
            last;
        }
        my $prev_id = $self->_pos_token('prev', $expr_id, \@key_ids);
        last if $prev_id eq $self->storage->_boundary_token_id;
        unshift @token_ids, $prev_id;
        $expr_id = $self->_expr_id([@token_ids[0..$order-1]]);
    } continue {
        $i++;
    }

    # translate token ids to token spacing/text
    my @reply;
    for my $id (@token_ids) {
        if (!exists $token_cache{$id}) {
            $self->storage->sth->{token_info}->execute($id);
            $token_cache{$id} = [$self->storage->sth->{token_info}->fetchrow_array];
        }
        push @reply, $token_cache{$id};
    }
    return \@reply;
}

sub learn {
    my ($self, $tokens) = @_;
    my $order = $self->storage->order;

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
            $self->storage->sth->{inc_token_count}->execute($_) for uniq(@expr);
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
    return if !@$token_ids;

    my %links;
    for my $id (@$token_ids) {
        next if exists $links{$id};
        $self->storage->sth->{token_count}->execute($id);
        $links{$id} = $self->storage->sth->{token_count}->fetchrow_array;
    }

    # remove tokens which are too rare
    my @ids = grep { $links{$_} >= $min } @$token_ids;

    @ids = sort { $links{$a} <=> $links{$b} } @ids;

    return @ids;
}

# increase the link weight between an expression and a token
sub _inc_link {
    my ($self, $type, $expr_id, $token_id) = @_;

    $self->storage->sth->{"${type}_count"}->execute($expr_id, $token_id);
    my $count = $self->storage->sth->{"${type}_count"}->fetchrow_array;

    if (defined $count) {
        $self->storage->sth->{"${type}_inc"}->execute($expr_id, $token_id);
    }
    else {
        $self->storage->sth->{"${type}_add"}->execute($expr_id, $token_id);
    }

    return;
}

# add new expression to the database
sub _add_expr {
    my ($self, $token_ids) = @_;

    # add the expression
    $self->storage->sth->{add_expr}->execute(@$token_ids);
    return $self->storage->dbh->last_insert_id(undef, undef, "expr", undef);
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $tokens) = @_;
    $self->storage->sth->{expr_id}->execute(@$tokens);
    return $self->storage->sth->{expr_id}->fetchrow_array();
}

# return token id if the token exists
sub _token_id {
    my ($self, $token_info) = @_;

    $self->storage->sth->{token_id}->execute(@$token_info);
    my $token_id = $self->storage->sth->{token_id}->fetchrow_array();

    return if !defined $token_id;
    return $token_id;
}

# get token id (adding the token if it doesn't exist)
sub _token_id_add {
    my ($self, $token_info) = @_;

    my $token_id = $self->_token_id($token_info);
    $token_id = $self->_add_token($token_info) if !defined $token_id;
    return $token_id;
}

# return all tokens (regardless of spacing) that consist of this text
sub _token_similar {
    my ($self, $token_text) = @_;
    $self->storage->sth->{token_similar}->execute($token_text);
    return $self->storage->sth->{token_similar}->fetchrow_arrayref;
}

# add a new token and return its id
sub _add_token {
    my ($self, $token_info) = @_;
    $self->storage->sth->{add_token}->execute(@$token_info);
    return $self->storage->dbh->last_insert_id(undef, undef, "token", undef);
}

# return a random expression containing the given token
sub _random_expr {
    my ($self, $token_id) = @_;

    my $expr;

    if (!defined $token_id) {
        $self->storage->sth->{random_expr}->execute();
        $expr = $self->storage->sth->{random_expr}->fetchrow_arrayref();
    }
    else {
        # try the positions in a random order
        for my $pos (shuffle 0 .. $self->storage->order-1) {
            my $column = "token${pos}_id";

            # get a random expression which includes the token at this position
            $self->storage->sth->{"expr_by_$column"}->execute($token_id);
            $expr = $self->storage->sth->{"expr_by_$column"}->fetchrow_arrayref();
            last if defined $expr;
        }
    }

    return if !defined $expr;
    return @$expr;
}

# return a new next/previous token
sub _pos_token {
    my ($self, $pos, $expr_id, $key_tokens) = @_;

    $self->storage->sth->{"${pos}_token_get"}->execute($expr_id);
    my $pos_tokens = $self->storage->sth->{"${pos}_token_get"}->fetchall_hashref('token_id');

    if (defined $key_tokens) {
        for my $i (0 .. $#{ $key_tokens }) {
            next if !exists $pos_tokens->{ @$key_tokens[$i] };
            return splice @$key_tokens, $i, 1;
        }
    }

    my @novel_tokens;
    for my $token (keys %$pos_tokens) {
        push @novel_tokens, ($token) x $pos_tokens->{$token}{count};
    }
    return $novel_tokens[rand @novel_tokens];
}

__PACKAGE__->meta->make_immutable;
