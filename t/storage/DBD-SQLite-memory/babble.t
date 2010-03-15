use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More tests => 30;

my $test = Hailo::Test->new(
    storage => "SQLite",
);
$test->test_babble;
