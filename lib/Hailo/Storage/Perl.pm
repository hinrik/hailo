package Hailo::Storage::Perl;

use Moose;
use MooseX::Types::Moose qw<HashRef Int Str>;
use Storable;
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

has file => (
    isa => Str,
    is  => 'ro',
);

has order => (
    isa     => Int,
    is      => 'ro',
    default => sub { shift->memory->{order} },
);

has _memory => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    init_arg   => undef,
);

with 'Hailo::Storage';

sub _build__memory {
    my ($self) = @_;

    if (defined $self->file && -s $self->file) {
        return retrieve($self->file);
    }
    else {
        # TODO: these data structures aren't very normalized, so they take up
        # much more memory than necessary
        return {
            token      => { }, # $token => \@ehash_of_exprs_that_contain_it
            expr       => { }, # $ehash => \@tokens_it_contains
            next_token => { }, # $ehash => \%tokens_that_can_follow_this_expr
            prev_token => { }, # $ehash => \%tokens_that_can_precede_this_expr
            order      => $self->order,
        };
    }
}

sub add_expr {
    my ($self, %args) = @_;
    my $mem = $self->_memory;

    my $ehash = _hash_tokens($args{tokens});
    $mem->{expr}{$ehash} = $args{tokens};

    for my $token (@{ $args{tokens} }) {
        $mem->{token}{$token} = [ ] if !exists $mem->{token}{$token};
        push @{ $mem->{token}{$token} }, $ehash;
    }

    for my $pos_token (qw(next_token prev_token)) {
        if (exists $args{$pos_token}) {
            $mem->{$pos_token}{$ehash}{ $args{$pos_token} }++;
        }
    }
    
    return;
}

sub token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->_memory->{token}{$token};
    return;
}

sub random_expr {
    my ($self, $token) = @_;
    my @ehash = @{ $self->_memory->{token}{$token} };
    return @{ $self->_memory->{expr}{ $ehash[rand @ehash] } };
}

sub next_tokens {
    my ($self, $expr) = @_;
    my $ehash = _hash_tokens($expr);
    return $self->_memory->{next_token}{ $ehash };
}

sub prev_tokens {
    my ($self, $expr) = @_;
    my $ehash = _hash_tokens($expr);
    return $self->_memory->{prev_token}{ $ehash };
}

# hash the contents of an expression for unique identification
# pretty naïve so far, just joins all the tokens with ASCII escapes
# since newlines aren't allowed
sub _hash_tokens {
    my ($tokens) = @_;
    my $ehash = join "\x03", @$tokens;
    return $ehash;
}

sub save {
    my ($self) = @_;
    store($self->_memory, $self->file);
    return;
}

sub start_training {
    my ($self) = @_;
    return;
}

sub stop_training {
    my ($self) = @_;
    return;
}

__PACKAGE__->meta->make_immutable;

1;

=encoding utf8

=head1 NAME

Hailo::Storage::Perl - A storage backend for L<Hailo|Hailo> using Perl structures

=head1 DESCRIPTION

This backend maintains information in a Perl hash, with an option to
save to/load from a file with L<Storable|Storable>.

It is fast, but uses a lot of memory.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
