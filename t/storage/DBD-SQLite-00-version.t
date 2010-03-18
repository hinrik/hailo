use 5.010;
use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Test::More tests => 1;

my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:","","", { sqlite_unicode => 1 });

my $sqlv = $dbh->{sqlite_version} // '';
my $sqlu = $dbh->{sqlite_unicode} // '';

diag("Using DBD::SQLite version '$DBD::SQLite::VERSION'/'$sqlv'; unicode:'$sqlu'");
pass("Version emitting successful");


