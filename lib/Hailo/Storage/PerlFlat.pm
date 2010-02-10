package Hailo::Storage::PerlFlat;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use Storable;
use Digest::MD4 qw(md4_hex);
use List::MoreUtils qw(uniq);
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends 'Hailo::Storage::Perl';

with qw(Hailo::Role::Generic
        Hailo::Role::Storage);

sub _build__memory {
    my ($self) = @_;
    if (defined $self->brain && -s $self->brain) {
        return retrieve($self->brain);
    } else {
        return {};
    }
}

sub add_expr {
    my ($self, $args) = @_;
    my $mem = $self->_memory;

    my $ehash = $self->_hash_tokens($args->{tokens});

    if (!exists $mem->{"expr-$ehash"}) {
        my $count = $#{ $args->{tokens} };
        $mem->{"expr-$ehash"} = $count;
        $mem->{"expr-$ehash-$_"} = $args->{tokens}->[$_] for 0 .. $count;

        for my $token (@{ $args->{tokens} }) {
            my $count = 0;
            if (exists $mem->{"token-$token"}) {
                $count = $mem->{"token-$token"} + 1;
                $mem->{"token-$token"} = $count;
            } else {
                $mem->{"token-$token"} = $count;
            }

            $mem->{"token-$token-$count"} = $ehash;
        }
    }

    for my $pos_token (qw(next_token prev_token)) {
        if (defined $args->{$pos_token}) {
            my $count = 0;
            if (exists $mem->{"$pos_token-$ehash"}) {
                $count = $mem->{"$pos_token-$ehash"} + 1;
                $mem->{"$pos_token-$ehash"} = $count;
            } else {
                $mem->{"$pos_token-$ehash"} = $count;
            }

            $mem->{"$pos_token-$ehash"} = $count;
            $mem->{"$pos_token-$ehash-$count"} = $args->{$pos_token};
            $mem->{"$pos_token-$ehash-token-$args->{$pos_token}"}++;
        }
    }

    $mem->{"prev_token-$ehash-token-"}++ if $args->{can_start};
    $mem->{"next_token-$ehash-token-"}++ if $args->{can_end};

    return;
}

sub token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->_memory->{"token-$token"};
    return;
}

sub random_expr {
    my ($self, $token) = @_;
    my $mem = $self->_memory;
    my $token_num = int rand $mem->{"token-$token"};
    my $ehash     = $mem->{"token-$token-$token_num"};
    my @tokens    = map { $mem->{"expr-$ehash-$_" } } 0 .. $mem->{"expr-$ehash"};
    return @tokens;
}

sub next_tokens {
    my ($self, $tokens) = @_;
    my $ehash = $self->_hash_tokens($tokens);

    return $self->_x_tokens("next_token", $ehash);
}

sub prev_tokens {
    my ($self, $tokens) = @_;
    my $ehash = $self->_hash_tokens($tokens);
    return $self->_x_tokens("prev_token", $ehash);
}

sub _x_tokens {
    my ($self, $pos_token, $ehash) = @_;
    my $mem = $self->_memory;
    my $key = "$pos_token-$ehash";

    return unless exists $mem->{$key};

    my $count = $mem->{$key};

    my %tokens = (
        map {
            my $k = $mem->{"$key-$_"};
            $k => $mem->{"$key-token-$k"}
        } 0 .. $count,
    );

    return \%tokens;
}

sub _hash_tokens {
     my ($self, $tokens) = @_;
     my $ehash = md4_hex("@$tokens");
     return substr $ehash, 0, 10;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::PerlFlat - A storage backend for L<Hailo|Hailo> using flat Perl structures

=head1 DESCRIPTION

This backend maintains information in a flat Perl hash, with an option
to save to/load from a file with L<Storable|Storable>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

