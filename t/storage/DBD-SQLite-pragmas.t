use 5.010;
use strict;
use warnings;
use Test::More tests => 5;
use Hailo;

my %pragmas = (
    auto_vacuum  => 1,
    cache_size   => 3000,
    encoding     => "UTF-8",
    journal_mode => 'OFF',
    synchronous  => 0,
);

my $hailo = Hailo->new(
    print_progress => 0,
    brain_resource => ':memory:',
    storage_class => 'SQLite',
    storage_args  => {
        pragmas => \%pragmas,
    },
);

$hailo->learn("hello there good sir");

# Test that pragmas were set
my $dbh = $hailo->_storage_obj->dbh;

while (my ($k, $v) = each %pragmas) {
    my $res = $dbh->selectrow_array("PRAGMA $k;");
    is(uc($res), $v, "PRAGMA $k was set correctly");
}
