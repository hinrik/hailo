use 5.010;
use strict;
use warnings;
use Test::More tests => 4;
use Hailo::Storage;
use Hailo::Storage::SQLite;
use Hailo::Storage::MySQL;
use Hailo::Storage::PostgreSQL;

my $sql    = Hailo::Storage->new;
my $pg     = Hailo::Storage::PostgreSQL->new;
my $sqlite = Hailo::Storage::SQLite->new;
my $mysql  = Hailo::Storage::MySQL->new;

# SQL
is_deeply(
    $sql->dbd_options,
    {
        RaiseError => 1,
    },
    "Storage options"
);

# Pg
is_deeply(
    $pg->dbd_options,
    {
        pg_enable_utf8 => 1,
        RaiseError => 1,
    },
    "PostgreSQL options"
);

# SQLite
is_deeply(
    $sqlite->dbd_options,
    {
        sqlite_unicode => 1,
        RaiseError => 1,
    },
    "SQLite options"
);

# mysql
is_deeply(
    $mysql->dbd_options,
    {
        mysql_enable_utf8 => 1,
        RaiseError => 1,
    },
    "MySQL options"
);
