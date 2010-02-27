package Hailo::Role::Storage;
use 5.010;
use MooseX::Role::Strict;
use MooseX::Types::Moose qw<Str Int>;
use List::Util qw<min>;
use namespace::clean -except => 'meta';

our $VERSION = '0.19';

has brain => (
    isa => Str,
    is  => 'rw',
);

has order => (
    isa => Int,
    is  => 'rw',
);

has repeat_limit => (
    isa     => Int,
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $order = $self->order;
        return min(($order * 10), 50);
    }
);

requires 'ready';
requires 'save';
requires 'learn_tokens';
requires 'make_reply';
requires 'start_learning';
requires 'stop_learning';
requires 'start_training';
requires 'stop_training';

1;

=encoding utf8

=head1 NAME

Hailo::Role::Storage - A role representing a L<Hailo|Hailo> storage backend

=head1 ATTRIBUTES

=head2 C<ready>

A method might be called after the storage has been constructed to ask
the storage if it considers itself ready to go. E.g. a storage that
requires a C<brain> would return false if it wasn't passed one.

=head2 C<order>

The Markov order (chain length) being used.

=head2 C<brain>

The name of the resource (file name, database name) to use as storage.

=head1 METHODS

=head2 C<new>

This is the constructor. It accept the attributes specified in
L</ATTRIBUTES>.

=head2 C<save>

Saves the current state.

=head2 C<learn_tokens>

Learns from a sequence of tokens. Takes an array reference of strings.

=head2 C<make_reply>

Takes an (optional) array reference of tokens and returns a reply (arrayref
of tokens) that might be relevant.

=head2 C<token_total>

Takes no arguments. Returns the number of tokens the brain knows.

=head2 C<expr_total>

Takes no arguments. Returns the number of expressions the brain knows.

=head2 C<start_learning>

Takes no arguments. This method is called by C<Hailo|Hailo> right before learning
begins.

=head2 C<stop_learning>

Takes no arguments. This method is called by C<Hailo|Hailo> right after learning
finishes.

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
