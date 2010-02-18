use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

Hailo::Test->new( storage => 'mysql' )->test_all_plan('known');
