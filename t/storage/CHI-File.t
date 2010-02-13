use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

eval "use CHI::File";
plan skip_all => "CHI::File not available";

my $test = Hailo::Test->new(
    storage => "CHI::File",
);
$test->test_all_plan('known');
