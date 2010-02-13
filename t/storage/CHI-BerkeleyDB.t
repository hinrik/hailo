use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

eval "use CHI::BerkeleyDB";
plan skip_all => "CHI::BerkeleyDB not available";

my $test = Hailo::Test->new(
    storage => "CHI::BerkeleyDB",
);
$test->test_all_plan;
