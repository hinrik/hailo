package Hailo::Storage::CHI;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use CHI;
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends 'Hailo::Storage::PerlFlat';

with qw(Hailo::Role::Generic
        Hailo::Role::Storage
        Hailo::Role::Log);

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

# XXX: This is broken somehow!
sub _increment {
    my ($self, $k) = @_;
    my $mem = $self->_memory;

    $self->meh->trace("Incrementing $k");

    if ($self->_exists($k)) {
        my $now = $self->_get($k);
        return $self->_set($k, $now + 1);
    } else {
        $self->_set($k, 0);
        return 0;
    }
}

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

