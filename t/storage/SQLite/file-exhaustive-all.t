use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan(skip_all => "Set TEST_EXHAUSTIVE_ALL= to run all exhaustive tests, these take a lot of time") unless $ENV{TEST_EXHAUSTIVE_ALL};

my $test = Hailo::Test->new(
    storage => "SQLite",
    in_memory => 0,
    exhaustive => 1,
    brief => 0,
);
$test->test_all_plan;
