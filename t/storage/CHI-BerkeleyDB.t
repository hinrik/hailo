use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "The Badger Test is broken with CHI::BerkeleyDB";

my $test = Hailo::Test->new(
    storage => "CHI::BerkeleyDB",
);
$test->test_all_plan('known');
