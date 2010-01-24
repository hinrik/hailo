package Hailo::Storage;
use Moose::Role;

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

Hailo::Storage - Superclass for a L<Hailo|Hailo> storage backend

=head1 METHODS

B<Note:> all of the following methods must be overridden by tokenizer
subclasses.

=head2 C<new>

Returns a new storage backend object.

Takes the following arguments:

B<'order'>, the Markov order of the bot.

B<'file'>, the which the backend will save to/load from.

=head2 C<order>

Returns the Markov order being used. Takes no arguments.

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
