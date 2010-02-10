package Hailo::Storage::CHI;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<HashRef>;
use CHI;
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends qw(Hailo::Storage::Mixin::Hash::Flat);

with qw(Hailo::Role::Generic
        Hailo::Role::Storage
        Hailo::Role::Log);

has _memory => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    init_arg   => undef,
);

sub _build__memory {
    my ($self) = @_;
 
    return $self->_memory_area;
}

has 'chi' => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_chi {
    my ($self) = @_;

    # XXX: Hardcoded for now
    my $cache = CHI->new(
        driver => 'Memory',
        global => 1
    );

    return $cache;
}

sub _exists {
    my ($self, $k) = @_;
    my $chi = $self->chi;

    $self->meh->trace("Checking if '$k' exists");

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

    $self->meh->trace("Setting '$k' = '$v'");

    $chi->set($k, $v, "never");
}

sub _get {
    my ($self, $k) = @_;
    my $chi = $self->chi;

    $self->meh->trace("Getting '$k'");
    my $v = $chi->get($k);
    $self->meh->trace("Value for '$k' is '" . ($v // 'undef') . "'");
    return $v;
}

sub _increment {
    my ($self, $k) = @_;

    $self->meh->trace("Incrementing $k");

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

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::CHI - A storage backend for L<Hailo|Hailo> using L<CHI>

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

