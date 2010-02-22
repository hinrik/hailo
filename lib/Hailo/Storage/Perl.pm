package Hailo::Storage::Perl;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<HashRef Int Str>;
use Storable;
use namespace::clean -except => 'meta';

our $VERSION = '0.16';

extends qw(Hailo::Storage::Mixin::Hash
           Hailo::Storage::Mixin::Storable);

with qw(Hailo::Role::Generic
        Hailo::Role::Storage);

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Perl - A storage backend for L<Hailo|Hailo> using Perl structures

=head1 DESCRIPTION

This backend maintains information in a Perl hash, with an option to
save to/load from a file with L<Storable|Storable>.

It is fast, but uses a lot of memory.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
