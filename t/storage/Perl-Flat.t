use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => 'Perl::Flat backend needs to be updated';
my $test = Hailo::Test->new(
    storage => "Perl::Flat",
);
$test->test_all_plan('known');
