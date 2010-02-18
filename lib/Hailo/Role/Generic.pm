package Hailo::Role::Generic;
use 5.010;
use MooseX::Role::Strict;
use MooseX::Types::Moose qw/HashRef/;
use namespace::clean -except => 'meta';

our $VERSION = '0.15';

has arguments => (
    isa           => HashRef,
    is            => 'ro',
    documentation => "Arguments passed from Hailo",
    auto_deref    => 1,
);

1;

=encoding utf8

=head1 NAME

Hailo::Role::Generic - A role used by all other L<Hailo|Hailo> roles

=head1 ATTRIBUTES

=head2 C<arguments>

A C<HashRef> of arguments passed to us from L<Hailo|Hailo>'s
L<storage|Hailo/storage_args>, or
L<tokenizer|Hailo/tokenizer_args> arguments.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

