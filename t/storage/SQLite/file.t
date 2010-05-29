use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

my $test = Hailo::Test->new(
    storage => "SQLite",
    in_memory => 0,
);
$test->test_all_plan;
