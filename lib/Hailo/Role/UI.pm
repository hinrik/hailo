package Hailo::Role::UI;
use 5.10.0;
use Moose::Role;
use namespace::clean -except => 'meta';

our $VERSION = '0.07';

requires 'run';

1;

=encoding utf8

=head1 NAME

Hailo::Role::UI - A role representing a L<Hailo|Hailo> UI

=head1 METHODS

=head2 C<new>

This is the constructor. It takes no arguments.

=head2 C<run>

Run the UI, a L<Hailo|Hailo> object will be the first and only
argument.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
