package Hailo::Storage::Mixin::Hash;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<HashRef>;
use namespace::clean -except => 'meta';

our $VERSION = '0.09';

has _memory_area => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    init_arg   => undef,
);

sub _build__memory_area {
    my ($self) = @_;

    # TODO: these data structures aren't very normalized, so they take up
    # much more memory than necessary
    my %mem = (
        token      => { }, # $token => \@ehash_of_exprs_that_contain_it
        expr       => { }, # $ehash => \@tokens_it_contains
        next_token => { }, # $ehash => \%tokens_that_can_follow_this_expr
        prev_token => { }, # $ehash => \%tokens_that_can_precede_this_expr
        order      => $self->order,
        separator  => $self->token_separator,
    );

    return \%mem;
}

sub learn_tokens {
    my ($self, $tokens) = @_;
    my $order = $self->order;

    for my $i (0 .. @$tokens - $order) {
        my @expr = map { $tokens->[$_] } ($i .. $i+$order-1);
        my $ehash = $self->_hash_tokens(\@expr);

        if (!$self->_expr_exists($ehash)) {
            $self->_expr_add_tokens($ehash, \@expr);

            for my $token (@expr) {
                $self->_token_push_ehash($token, $ehash);
            }
        }

        # add next token for this expression, if any
        if ($i < @$tokens - $order) {
            my $next = $tokens->[$i+$order];
            $self->_pos_token_ehash_increment('next_token', $ehash, $next);
        }

        # add previous token for this expression, if any
        if ($i > 0) {
            my $prev = $tokens->[$i-1];
            $self->_pos_token_ehash_increment('prev_token', $ehash, $prev);
        }

        $self->_pos_token_ehash_increment('prev_token', $ehash, '') if $i == 0;
        $self->_pos_token_ehash_increment('next_token', $ehash, '') if $i == @$tokens-$order;
    }

    return;
}

sub make_reply {
    my ($self, $key_tokens) = @_;
    my $order = $self->order;

    my @keys = grep { $self->_token_exists($_) } @$key_tokens;
    return if !@keys;
    my @reply = $self->_random_expr(shift @keys);
    my $repeat_limit = $self->repeat_limit;

    my $i = 0;
    while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit and uniq(@reply) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }
        my $next_token = $self->_pos_token('next', [@reply[-$order..-1]], \@keys);
        last if $next_token eq '';
        push @reply, $next_token;
    } continue {
        $i++;
    }

    $i = 0;
    while (1) {
        if (($i % $order) == 0 and 
            (($i >= $repeat_limit and uniq(@reply) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }   
        my $prev_token = $self->_pos_token('prev', [@reply[0..$order-1]], \@keys);
        last if $prev_token eq ''; 
        unshift @reply, $prev_token;
    } continue {
        $i++;
    }

    return \@reply;
}

sub _expr_exists {
    my ($self, $ehash) = @_;
    my $mem = $self->_memory;

    return exists $mem->{expr}{$ehash};
}

sub _expr_add_tokens {
    my ($self, $ehash, $tokens) = @_;
    my $mem = $self->_memory;

    $mem->{expr}{$ehash} = $tokens;
    return;
}

sub _token_push_ehash {
    my ($self, $token, $ehash) = @_;
    my $mem = $self->_memory;

    $mem->{token}{$token} = [ ] if !exists $mem->{token}{$token};
    push @{ $mem->{token}{$token} }, $ehash;
    return;
}

sub _pos_token_ehash_increment {
    my ($self, $pos_token, $ehash, $token) = @_;
    my $mem = $self->_memory;

    $mem->{$pos_token}{$ehash}{ $token }++;
    return;
}

sub _token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->_memory->{token}{$token};
    return;
}

sub _random_expr {
    my ($self, $token) = @_;
    my @ehash = @{ $self->_memory->{token}{$token} };
    return @{ $self->_memory->{expr}{ $ehash[rand @ehash] } };
}

sub _pos_token {
    my ($self, $pos, $tokens, $key_tokens) = @_;

    my $ehash = $self->_hash_tokens($tokens);
    my $pos_tokens = $self->_memory->{"${pos}_token"}{ $ehash };

    if (defined $key_tokens) {
        for my $i (0 .. $#{ $key_tokens }) {
            next if !exists $pos_tokens->{ @$key_tokens[$i] };
            return splice @$key_tokens, $i, 1;
        }   
    }   

    my @novel_tokens;
    for my $token (keys %$pos_tokens) {
        push @novel_tokens, ($token) x $pos_tokens->{$token};
    }   
    return @novel_tokens[rand @novel_tokens];
}

# concatenate contents of an expression for unique identification
sub _hash_tokens {
    my ($self, $tokens) = @_;
    my $ehash = join $self->token_separator, @$tokens;
    return $ehash;
}

sub start_training { return }
sub stop_training  { return }
sub start_learning { return }
sub stop_learning  { return }

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Mixin::Hash - A mixin class for L<storage|Hailo::Role::Storage> classes using a C<HashRef>

=head1 DESCRIPTION

This skeleton mixin backend maintains information in a Perl C<HashRef>.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
