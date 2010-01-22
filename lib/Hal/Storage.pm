package Hal::Storage;

use strict;
use warnings;
use Carp 'croak';

sub new             { croak 'Not implemented!' };
sub order           { croak 'Not implemented!' };
sub save            { croak 'Not implemented!' };
sub add_blurb       { croak 'Not implemented!' };
sub find_blurb      { croak 'Not implemented!' };
sub random_blurb    { croak 'Not implemented!' };
sub token_exists    { croak 'Not implemented!' };
sub next_tokens     { croak 'Not implemented!' };
sub prev_tokens     { croak 'Not implemented!' };

1;

=encoding utf8

=head1 NAME

Hal::Storage - Superclass for a L<Hal|Hal> storage backend

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

=head2 C<add_blurb>

Adds a new blurb. Takes the follwing arguments:

B<'blurb'>, a hash reference (see below).

B<'next_token'>, the token that succeeds this blurb, if any.

B<'next_token'>, the token that precedes this blurb, if any.

The blurb hash reference can have the following keys:

B<'can_start'>, should be true if the blurb occurred at the beginning of
a line.

B<'can_end'>, should be true if the blurb occurred at the end of a line.

B<'tokens'>, an array reference of the tokens in the blurb. The amount of
tokens should be equal to the return value of C<order|/order>.

=head2 C<find_blurb>

Takes a list of tokens (amount determined by C<order|/order>) as arguments
and returns the blurb hash reference which contains these tokens.

=head2 C<random_blurb>

Takes a single token as an argument and returns a randomly picked blurb
which contains it.

=head2 C<token_exists>

Takes a single token as an argument and returns a true value if the token
exists.

=head2 C<next_tokens>

Takes a blurb hash reference as an argument and returns a hash reference.
The keys are all the tokens that can succeed the blurb.

=head2 C<prev_tokens>

Takes a blurb hash reference as an argument and returns a hash reference.
The keys are all the tokens that can precede the blurb.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
