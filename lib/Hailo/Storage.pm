package Hailo::Storage;

use Moose::Role;
use namespace::clean -except => 'meta';

requires 'file';
requires 'order';
requires 'save';
requires 'add_expr';
requires 'random_expr';
requires 'token_exists';
requires 'next_tokens';
requires 'prev_tokens';
requires 'start_training';
requires 'stop_training';

1;

=encoding utf8

=head1 NAME

Hailo::Storage - A role representing a L<Hailo|Hailo> storage backend

=head1 ATTRIBUTES

=head2 C<order>

The Markov order (chain length) being used.

=head2 C<file>

The filename to the permanent on-disk storage used by the backend.

=head1 METHODS

=head2 C<new>

This is the contructor. It accept the attributes specified in
L</ATTRIBUTES>.

=head2 C<save>

Saves the current state to a file.

=head2 C<add_expr>

Adds a new expression. Takes the follwing arguments:

B<'tokens'>, an array reference of the tokens that make up the expression.
The number of elements should be equal to the value returned by
C<order|/order>.

B<'next_token'>, the token that succeeds this expression, if any.

B<'next_token'>, the token that precedes this expression, if any.

=head2 C<random_expr>

Takes a single token as an argument and returns a randomly picked expression
which contains it.

=head2 C<token_exists>

Takes a single token as an argument and returns a true value if the token
exists.

=head2 C<next_tokens>

Takes an array reference of tokens arguments that make up an expression and
returns a list tokens that may succeed it.

=head2 C<prev_tokens>

Takes an array reference of tokens arguments that make up an expression and
returns a list tokens that may precede it.

=head2 C<start_training>

Takes no arguments. This method is called by C<Hailo|Hailo> right before training
begins.

=head2 C<stop_training>

Takes no arguments. This method is called by C<Hailo|Hailo> right after training
finishes.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
