use 5.010;
use strict;
use warnings;
use Test::More tests => 5;
use Hailo;

my %pragmas = (
    pragma_auto_vacuum  => 1,
    pragma_cache_size   => 3000,
    pragma_encoding     => "UTF-8",
    pragma_journal_mode => 'OFF',
    pragma_synchronous  => 0,
);

my $hailo = Hailo->new(
    brain         => ':memory:',
    storage_class => 'SQLite',
    storage_args  => { %pragmas },
);

$hailo->learn("hello there good sir");

# Test that pragmas were set
my $dbh = $hailo->_storage->dbh;

while (my ($k, $v) = each %pragmas) {
    my ($short) = $k =~ /^pragma_(.*)/;
    my $res = $dbh->selectrow_array("PRAGMA $short;");
    is(uc($res), $v, "PRAGMA $short was set correctly");
}
