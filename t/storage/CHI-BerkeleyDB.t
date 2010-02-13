use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "CHI::BerkeleyDB is broken, set TEST_BROKEN=1 to enable it" unless $ENV{TEST_BROKEN};

Hailo::Test->new( storage => 'CHI::BerkeleyDB' )->test_all_plan('known');
