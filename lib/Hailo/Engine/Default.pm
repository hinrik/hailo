package Hailo::Engine::Default;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw(Int);
use namespace::clean -except => 'meta';

our $VERSION = '0.09';

with qw(Hailo::Role::Generic
        Hailo::Role::Engine);

has storage => (
    required => 1,
    is       => 'ro',
);

has tokenizer => (
    required => 1,
    is       => 'ro',
);

sub reply {
    my ($self, $input) = @_;
    my $storage = $self->storage;
    my $toke    = $self->tokenizer;

    my @tokens = $toke->make_tokens($input);
    my @key_tokens = $toke->find_key_tokens(\@tokens);
    return if !@key_tokens;

    my $reply = $storage->make_reply(\@key_tokens);
    return if !defined $reply;
    return $toke->make_output($reply);
}

sub learn {
    my ($self, $input) = @_;
    my $storage = $self->storage;
    my $order   = $storage->order;

    my @tokens = $self->tokenizer->make_tokens($input);

    # only learn from inputs which are long enough
    return if @tokens < $order;

    $storage->learn_tokens(\@tokens);
    return;
}

=encoding utf8

=head1 NAME

Hailo::Engine::Default - The default engine backend for L<Hailo|Hailo>

=head1 DESCRIPTION

This backend implements the logic of replying to and learning from
input using the resources given to the L<engine
roles|Hailo::Role::Engine>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;
