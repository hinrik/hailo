use 5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

eval "use DBD::Pg";
plan skip_all => "DBD::Pg not available";

$SIG{__WARN__} = sub { print STDERR @_ if $_[0] !~ m/NOTICE:\s*CREATE TABLE/; };

my $test = Hailo::Test->new(
    storage => "Pg",
);
$test->test_all_plan;
