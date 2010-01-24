package Hal::Storage::Perl;
use Moose;
use MooseX::Types::Moose qw<HashRef Int Str>;
use namespace::clean -except => 'meta';
use Storable;

our $VERSION = '0.01';

has file => (
    isa    => Str,
    is     => 'ro',
);

has memory => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
);

has order => (
    isa    => Int,
    is     => 'ro',
    default => sub { shift->memory->{order} },
);

with 'Hal::Storage';

__PACKAGE__->meta->make_immutable;

sub _build_memory {
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
    my $mem = $self->memory;

    my $ehash = _hash_tokens($args{tokens});
    $mem->{expr}{$ehash} = $args{tokens};

    for my $token (@{ $args{tokens} }) {
        $mem->{token}{$token} = [ ] if !exists $mem->{token}{$token};
        push @{ $mem->{token}{$token} }, $ehash;
    }

    if (defined $args{next_token}) {
        if (!exists $mem->{next_token}{$ehash}{$args{next_token}}) {
            $mem->{next_token}{$ehash}{$args{next_token}} = undef;
        }
    }

    if (defined $args{prev_token}) {
        if (!exists $mem->{prev_token}{$ehash}{$args{prev_token}}) {
            $mem->{prev_token}{$ehash}{$args{prev_token}} = undef;
        }
    }
    
    return;
}

sub token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->memory->{token}{$token};
    return;
}

sub random_expr {
    my ($self, $token) = @_;
    my @ehash = @{ $self->memory->{token}{$token} };
    return @{ $self->memory->{expr}{ $ehash[rand @ehash] } };
}

sub next_tokens {
    my ($self, $expr) = @_;
    my $ehash = _hash_tokens($expr);
    return keys %{ $self->memory->{next_token}{ $ehash } };
}

sub prev_tokens {
    my ($self, $expr) = @_;
    my $ehash = _hash_tokens($expr);
    return keys %{ $self->memory->{prev_token}{ $ehash } };
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
    store($self->memory, $self->file);
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

1;

=encoding utf8

=head1 NAME

Hal::Storage::Perl - A storage backend for L<Hal|Hal> using Perl structures

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
