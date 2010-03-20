package Hailo::Role::Engine;

use 5.10.0;
use Any::Moose '::Role';
use Any::Moose 'X::Types::'.any_moose() => [qw< Int >];
use namespace::clean -except => 'meta';

has storage => (
    required      => 1,
    is            => 'ro',
    documentation => "Our copy of the current Storage object",
);

has order => (
    required      => 1,
    isa           => Int,
    is            => 'ro',
    documentation => "Our copy of the current markov order",
);

requires 'learn';
requires 'reply';

1;

=encoding utf8

=head1 NAME

Hailo::Role::Engine - A role representing a L<Hailo|Hailo> engine backend

=head1 ATTRIBUTES

A C<Hailo::Engine::*> gets the following attributes by using this role:

=head2 C<storage>

A L<storage|Hailo::Role::Storage> object the engine should use to get data from.

=head2 C<order>

The current Markov order used by the storage object.

=head1 METHODS

=head2 C<new>

This is the constructor. It accept the attributes specified in
L</ATTRIBUTES>.

=head2 C<learn>

Learn from the given input and add it to storage.

=head2 C<reply>

Reply to the given input using the storad data.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
