use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

eval "use CHI::Memory";
plan skip_all => "CHI::Memory not available";

my $test = Hailo::Test->new(
    storage => "CHI::Memory",
);
$test->test_all_plan('known');
