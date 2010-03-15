use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "You need the optional DBD::mysql module for MySQL support" unless eval "require DBD::mysql;";

Hailo::Test->new( storage => 'mysql' )->test_all_plan;
