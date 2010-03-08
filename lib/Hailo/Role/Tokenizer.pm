package Hailo::Role::Tokenizer;
use 5.010;
use Any::Moose '::Role';
use namespace::clean -except => 'meta';

requires 'make_tokens';
requires 'make_output';

1;

=encoding utf8

=head1 NAME

Hailo::Role::Tokenizer - A role representing a L<Hailo|Hailo> tokenizer

=head1 METHODS

=head2 C<new>

This is the constructor. It takes no arguments.

=head2 C<make_tokens>

Takes a line of input and returns an array reference of tokens.

=head2 C<make_output>

Takes an array reference of tokens and returns a line of output.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
