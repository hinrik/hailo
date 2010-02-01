package Hailo::Engine::Default;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw(Int);
use List::Util qw(min shuffle);
use List::MoreUtils qw(uniq);
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

with qw(Hailo::Role::Generic
        Hailo::Role::Engine);

has storage => (
    required => 1,
    is       => 'ro',
);

has tokenizer => (
    required => 1,
    is       => 'ro',
);

has _repeat_limit => (
    isa       => Int,
    is        => 'ro',
    lazy      => 1,
    default   => sub {
        my ($self) = @_;
        my $order = $self->storage->order;

        return min(($order * 10), 50);
    },
);

sub reply {
    my ($self, $input) = @_;
    my $storage  = $self->storage;
    my $order    = $storage->order;
    my $toke     = $self->tokenizer;

    $input = $self->_clean_input($input);
    my @tokens = $toke->make_tokens($input);
    my @key_tokens = shuffle grep { $storage->token_exists($_) }
                             $toke->find_key_tokens(\@tokens);
    return if !@key_tokens;
    my $key_token = shift @key_tokens;

    my ($can_start, $can_end, @middle_expr) = $storage->random_expr($key_token);
    my @reply = @middle_expr;
    my @expr = @middle_expr;

    my $repeat_limit = $self->_repeat_limit;

    # construct the end of the reply
    my $i = 0; while (!$can_end) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit and uniq(@reply) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }
        my $next_tokens = $storage->next_tokens(\@expr);
        my $next_token = $self->_pos_token($next_tokens, \@key_tokens);
        push @reply, $next_token;
        @expr = (@expr[1 .. $order-1], $next_token);
        (undef, $can_end) = $storage->expr_can(\@expr);
    } continue {
        $i++;
    }

    @expr = @middle_expr;

    # construct the beginning of the reply
    $i = 0; while (!$can_start) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit and uniq(@reply) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }
        my $prev_tokens = $storage->prev_tokens(\@expr);
        my $prev_token = $self->_pos_token($prev_tokens, \@key_tokens);
        unshift @reply, $prev_token;
        @expr = ($prev_token, @expr[0 .. $order-2]);
        ($can_start, undef) = $storage->expr_can(\@expr);
    } continue {
        $i++;
    }

    return $toke->make_output(\@reply);
}

sub learn {
    my ($self, $input) = @_;
    my $storage  = $self->storage;
    my $order    = $storage->order;

    $input = $self->_clean_input($input);
    my @tokens = $self->tokenizer->make_tokens($input);

    # only learn from inputs which are long enough
    return if @tokens < $order;

    for my $i (0 .. @tokens - $order) {
        my @expr = map { $tokens[$_] } ($i .. $i+$order-1);

        my ($next_token, $prev_token);
        $next_token = $tokens[$i+$order] if $i < @tokens - $order;
        $prev_token = $tokens[$i-1] if $i > 0;

        # store the current expression
        $storage->add_expr( {
            tokens     => \@expr,
            next_token => $next_token,
            prev_token => $prev_token,
            can_start  => ($i == 0 ? 1 : undef),
            can_end    => ($i == @tokens-$order ? 1 : undef),
        } );
    }

    return;
}

sub _pos_token {
    my ($self, $next_tokens, $key_tokens) = @_;
    my $storage = $self->storage;

    for my $i (0 .. $#{ $key_tokens }) {
        next if !exists $next_tokens->{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens;
    while (my ($token, $count) = each %$next_tokens) {
        push @novel_tokens, ($token) x $count;
    }
    return @novel_tokens[rand @novel_tokens];
}

sub _clean_input {
    my ($self, $input) = @_;
    my $separator = quotemeta $self->storage->token_separator;
    $input =~ s/$separator//g;
    return $input;
}

=encoding utf8

=head1 NAME

Hailo::Engine::Default - The default engine backend for L<Hailo|Hailo>

=head1 DESCRIPTION

This backend implements the logic of replying to and learning from
input using the resources given to the L<engine
roles|Hailo::Role::Engine>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
