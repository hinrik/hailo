use 5.10.0;
use strict;
use warnings;
use Test::More tests => 4;
use Hailo;
use Hailo::Storage::SQL;
use Hailo::Storage::Pg;
use Hailo::Storage::SQLite;
use Hailo::Storage::mysql;

my $sql    = Hailo::Storage::SQL->new;
my $pg     = Hailo::Storage::Pg->new;
my $sqlite = Hailo::Storage::SQLite->new;
my $mysql  = Hailo::Storage::mysql->new;

# SQL
is_deeply(
    $sql->dbd_options,
    {
        RaiseError => 1,
    },
    "SQL options"
);

# Pg
is_deeply(
    $pg->dbd_options,
    {
        pg_enable_utf8 => 1,
        RaiseError => 1,
    },
    "Pg options"
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
    "mysql options"
);


