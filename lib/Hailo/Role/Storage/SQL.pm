package Hailo::Role::Storage::SQL;
use Moose::Role;
use MooseX::Types::Moose qw<HashRef>;

has _dbh => (
    isa        => 'DBI::db',
    is         => 'ro',
    lazy_build => 1,
);

has _sth => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
);

1;

=encoding utf8

=head1 NAME

Hailo::Role::Storage::SQL - A an extension of L<Hailo::Role::Storage> for SQL backends

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
