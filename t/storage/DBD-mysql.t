use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

eval "use DBD::mysql";
plan skip_all => "DBD::mysql not available";

my $test = Hailo::Test->new(
    storage => "mysql",
);
$test->test_all_plan;
