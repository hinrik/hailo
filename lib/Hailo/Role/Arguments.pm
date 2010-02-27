package Hailo::Role::Arguments;
use 5.010;
use Any::Moose '::Role';
BEGIN {
    return unless Any::Moose::moose_is_preferred;
    require MooseX::Role::Strict;
    MooseX::Role::Strict->import;
}
use Any::Moose 'X::Types::'.any_moose() => [qw/HashRef/];
use namespace::clean -except => 'meta';

our $VERSION = '0.19';

has arguments => (
    isa           => HashRef,
    is            => 'ro',
    documentation => "Arguments passed from Hailo",
    auto_deref    => 1,
);

1;

=encoding utf8

=head1 NAME

Hailo::Role::Arguments - A role which adds an 'arguments' attribute

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

