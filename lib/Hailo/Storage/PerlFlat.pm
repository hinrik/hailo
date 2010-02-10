package Hailo::Storage::PerlFlat;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use Digest::MD4 qw(md4_hex);
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends 'Hailo::Storage::Perl';

with qw(Hailo::Role::Generic
        Hailo::Role::Storage);

sub _build__memory_area {
    # The hash we store all our data in
    my %memory;
    return \%memory;
}

sub _expr_exists {
    my ($self, $ehash) = @_;
    my $mem = $self->_memory;

    return exists $mem->{"expr-$ehash"};
}

sub _expr_add_tokens {
    my ($self, $ehash, $tokens) = @_;
    my $mem = $self->_memory;

    my $count = $#{ $tokens };
    $mem->{"expr-$ehash"} = $count;
    $mem->{"expr-$ehash-$_"} = $tokens->[$_] for 0 .. $count;

    return;
}

sub _token_push_ehash {
    my ($self, $token, $ehash) = @_;
    my $mem = $self->_memory;

    my $count = $mem->{"token-$token"}++;
    $mem->{"token-$token-$count"} = $ehash;

    return;
}

sub _pos_token_ehash_increment {
    my ($self, $pos_token, $ehash, $token) = @_;
    my $mem = $self->_memory;

    # XXX: Do we increment the count when the '' token gets added?
    my $count = $mem->{"$pos_token-$ehash"}++;
    $mem->{"$pos_token-$ehash"} = $count;
    $mem->{"$pos_token-$ehash-$count"} = $token;
    $mem->{"$pos_token-$ehash-token-$token"}++;

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

