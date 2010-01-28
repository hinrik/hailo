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
