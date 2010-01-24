package Hal::Tokenizer;
use Moose::Role;

requires 'find_key_tokens';
requires 'make_tokens';
requires 'make_output';

1;

=encoding utf8

=head1 NAME

Hal::Tokenizer - Superclass for a L<Hal|Hal> tokenizer

=head1 METHODS

B<Note:> all of the following methods must be overridden by tokenizer
subclasses.

=head2 C<new>

Returns a new tokenizer object.

=head2 C<make_tokens>

Takes a line of input and returns a list of tokens.

=head2 C<make_output>

Takes a list of tokens and returns a line of output.

=head2 C<find_key_tokens>

Takes a list of tokens and returns those which are deemed interesting enough
to base a reply on.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
