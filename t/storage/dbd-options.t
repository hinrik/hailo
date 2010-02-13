use 5.10.0;
use strict;
use warnings;
use Test::More tests => 4;
use Hailo;
use Hailo::Storage::Mixin::DBD;
use Hailo::Storage::DBD::Pg;
use Hailo::Storage::DBD::SQLite;
use Hailo::Storage::DBD::mysql;

my $sql    = Hailo::Storage::Mixin::DBD->new;
my $pg     = Hailo::Storage::DBD::Pg->new;
my $sqlite = Hailo::Storage::DBD::SQLite->new;
my $mysql  = Hailo::Storage::DBD::mysql->new;

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


