package Hailo::Storage::Mixin::CHI;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<HashRef>;
use CHI;
use Digest::MD4 qw(md4_hex);
use namespace::clean -except => 'meta';

our $VERSION = '0.11';

extends qw(Hailo::Storage::Mixin::Hash::Flat);

with qw(Hailo::Role::Generic
        Hailo::Role::Storage
        Hailo::Role::Log);

has 'chi' => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_chi {
    my ($self) = @_;

    my $cache = CHI->new(
        $self->chi_options,
    );

    return $cache;
}

has chi_options => (
    isa        => HashRef,
    is         => 'ro',
    auto_deref => 1,
    lazy_build => 1,
);

sub _build_chi_options {
    return {
        namespace => __PACKAGE__,
        serializer => __PACKAGE__->new,
        on_get_error => "die",
        on_set_error => "die",
    };
}

sub _exists {
    my ($self, $k) = @_;
    my $chi = $self->chi;

    # $self->meh->trace("Checking if '$k' exists");

    my $v = $self->_get($k);
    if (defined $v) {
        return 1;
    } else {
        return 0;
    }
}

sub _set {
    my ($self, $k, $v) = @_;
    my $chi = $self->chi;

    # $self->meh->trace("Setting '$k' = '$v'");

    return $chi->set($k, $v, "never");
}

sub _get {
    my ($self, $k) = @_;
    my $chi = $self->chi;

    # $self->meh->trace("Getting '$k'");
    my $v = $chi->get($k);
    # $self->meh->trace("Value for '$k' is '" . ($v // 'undef') . "'");
    return $v;
}

sub _increment {
    my ($self, $k) = @_;

    # $self->meh->trace("Incrementing $k");

    if (not $self->_exists($k)) {
        $self->_set($k, 1);
        return 0;
    } else {
        my $was = $self->_get($k);;
        $self->_set($k, $was + 1);
        return $was;
    }
}

sub save {}

sub _hash_tokens {
    my ($self, $tokens) = @_;
    my $ehash = md4_hex("@$tokens");
    return substr $ehash, 0, 12;
}

# CHI moronically insists on a seralizer even though we don't need it
sub serialize { return $_[1] }
sub deserialize { return $_[1] }
sub serializer { return 'YouSuck' }

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Mixin::CHI - A mixin class for L<Hailo>
L<storage|Hailo::Role::Storage> backends using L<CHI>

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
