package Hailo::Storage::CHI::BerkeleyDB;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

extends qw(Hailo::Storage::Mixin::CHI);

override _build_chi_options => sub {
    return {
        %{ super() },
        driver => 'BerkeleyDB',
        $_[0]->arguments,
    };
};

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::CHI::BerkeleyDB - A L<BerkeleyDB|CHI::Driver::BerkeleyDB> storage backend for L<Hailo|Hailo> using L<CHI>

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

