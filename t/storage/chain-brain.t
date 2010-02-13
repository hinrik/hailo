use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Test::More tests => 40;
use Hailo;
use Hailo::Test;
use Data::Random qw(:all);
use File::Temp qw(tempfile tempdir);

for my $backend (Hailo::Test::chain_storages()) {
    my ($fh, $filename) = tempfile( SUFFIX => '.db' );
    ok($filename, "Got temporary file $filename");

    my $test = Hailo::Test->new(
        storage => $backend,
        brain_resource => $filename,
    );

    $test->test_chaining;
}
