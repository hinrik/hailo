use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Test::More tests => 218;
use Hailo;
use Hailo::Test;
use Data::Random qw(:all);
use File::Temp qw(tempfile tempdir);

SKIP: {
    skip 'Perl backends need to be updated', 218;
    for my $backend (Hailo::Test::chain_storages()) {
        my $test = Hailo::Test->new(
            storage => $backend
        );

        $test->test_chaining;
    }
}
