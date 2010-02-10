package Hailo::Storage::PerlFlat;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use Digest::MD4 qw(md4_hex);
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends 'Hailo::Storage::Perl';

with qw(Hailo::Role::Generic
        Hailo::Role::Storage
        Hailo::Role::Log);

after _build__memory => sub {
    my ($self) = @_;
    $self->{_memory} = {};
};

sub add_expr {
    my ($self, $args) = @_;
    my $mem = $self->_memory;

    my $ehash = $self->_hash_tokens($args->{tokens});

    if (!exists $mem->{"expr-$ehash"}) {
        my $count = $#{ $args->{tokens} };
        $mem->{"expr-$ehash"} = $count;
        $mem->{"expr-$ehash-$_"} = $args->{tokens}->[$_] for 0 .. $count;

        for my $token (@{ $args->{tokens} }) {
            $mem->{token}{$token} = [ ] if !exists $mem->{token}{$token};

            my $count = 0;
            if (exists $mem->{"token-$token"}) {
                $count = $mem->{"token-$token"} + 1;
                $mem->{"token-$token"} = $count;
            } else {
                $mem->{"token-$token"} = $count;
            }

            push @{ $mem->{token}{$token} }, $ehash;
            $mem->{"token-$token-$count"} = $ehash;
        }
    }

    for my $pos_token (qw(next_token prev_token)) {
        if (defined $args->{$pos_token}) {
            $mem->{$pos_token}{$ehash}{ $args->{$pos_token} }++;
        }
    }

    $mem->{"prev_token-$ehash-"}++ if $args->{can_start};
    $mem->{"next_token-$ehash-"}++ if $args->{can_end};

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
    my $ehash = $ehash[rand @ehash];
    my @tokens = map { $self->_memory->{"expr-$ehash-$_" } } 0 .. $self->_memory->{"expr-$ehash"};
    return @tokens;
}

sub next_tokens {
    my ($self, $tokens) = @_;
    my $ehash = $self->_hash_tokens($tokens);
    return $self->_memory->{next_token}{ $ehash };
}

sub prev_tokens {
    my ($self, $tokens) = @_;
    my $ehash = $self->_hash_tokens($tokens);
    return $self->_memory->{prev_token}{ $ehash };
}

# concatenate contents of an expression for unique identification
sub _hash_tokens {
    my ($self, $tokens) = @_;
    my $ehash = md4_hex("@$tokens");
    return substr $ehash, 0, 10;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::PerlFlat - A storage backend for L<Hailo|Hailo> using Perl structures

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

