use 5.010;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More;

plan skip_all => "You need the optional DBD::Pg module for PostgreSQL support" unless eval "require DBD::Pg;";

Hailo::Test->new( storage => 'Pg' )->test_all_plan;
