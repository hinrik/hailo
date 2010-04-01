use 5.010;
use strict;
use warnings;
use Test::More tests => 50;
use DBI;
use File::Temp qw<tempdir tempfile>;

# Dir to store our brains
my $dir = tempdir( "hailo-test-dbd-exists-XXXX", CLEANUP => 1, TMPDIR => 1 );

for (1 .. 50) {
    subtest "Iteration $_/50" => sub {
        my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite', EXLOCK => 0 );

        ok(-e $brain_file, "$_: $brain_file -e");
        ok(-f $brain_file, "$_: $brain_file -f");
        cmp_ok(-s $brain_file, '==', 0, "$_: A new tempfile $brain_file has size 0");

        my $dbh = DBI->connect("dbi:SQLite:dbname=$brain_file","","");
        ok($dbh, "$_: Connected to SQLite file $brain_file");

        if ($_ >= 25) {
            pass("$_: Setting pragmas");
            $dbh->do('PRAGMA synchronous=OFF;');
            $dbh->do('PRAGMA journal_mode=OFF;');
        }

        ok(-e $brain_file, "$_: Database $brain_file -e");
        ok(-f $brain_file, "$_: Database $brain_file -f");
        cmp_ok(-s $brain_file, '==', 0, "$_: $_: A connected $brain_file has size 0");

        done_testing();
    };
}
