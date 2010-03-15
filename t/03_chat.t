use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo;
use Hailo::Test;
use Test::More tests => 1 * (my @x = Hailo::Test::simple_storages());

for my $storage (Hailo::Test::simple_storages()) {
    SKIP: {
        my $test = Hailo::Test->new(
            storage => $storage,
        );
        $test->test_congress;
    }
}

