use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "Perl::Flat backend is broken, set TEST_BROKEN=1 to enable it" unless $ENV{TEST_BROKEN};
my $test = Hailo::Test->new(
    storage => "Perl::Flat",
);
$test->test_all_plan('known');
