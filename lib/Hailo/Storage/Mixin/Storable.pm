package Hailo::Storage::Mixin::Storable;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<HashRef>;
use Storable;
use namespace::clean -except => 'meta';

our $VERSION = '0.10';

has _memory => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    init_arg   => undef,
);

sub _build__memory {
    my ($self) = @_;
    if (defined $self->brain && -s $self->brain) {
        return retrieve($self->brain);
    }
    else {
        return $self->_memory_area;
    }
}

sub save {
    my ($self) = @_;
    store($self->_memory, $self->brain);
    return;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Mixin::Storable - A mixin class for
L<storage|Hailo::Role::Storage> providing L<Storable> storage

=head1 DESCRIPTION

This skeleton mixin backend provides on-disk storage via L<Storable>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
