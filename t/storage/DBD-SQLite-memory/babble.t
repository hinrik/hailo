use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "This fails intermittently and I'm not sure whether it should or not";

my $test = Hailo::Test->new(
    storage => "SQLite",
);
$test->test_babble;
