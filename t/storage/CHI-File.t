use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "CHI::File takes forever to run, set TEST_CHI_FILE=1 to enable it" unless $ENV{TEST_CHI_FILE};

Hailo::Test->new( storage => 'CHI::File' )->test_all_plan('known');
