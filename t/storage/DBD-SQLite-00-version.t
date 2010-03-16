use 5.010;
use strict;
use warnings;
use DBI;
use DBD::SQLite;
use Test::More tests => 1;

my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:","","", { sqlite_unicode => 1 });

my $sqlv = $dbh->{sqlite_version} // '';
my $sqlu = $dbh->{sqlite_unicode} // '';

diag("We're using DBD::SQLite version '$DBD::SQLite::VERSION' which uses version '$sqlv' of SQLite with unicode set to '$sqlu'");
pass("Version emitting successful");


