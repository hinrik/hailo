use 5.010;
use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;

# Using both these modules and running the tests below gives silly
# "Use of uninitialized value $class in regexp compilation" warnings
# under Mouse.

use Hailo;
use Hailo::Command;

dies_ok { Hailo->new( order => undef ) } "undef order";
dies_ok { Hailo->new( order => "foo" ) } "Str order";

for (my $i = 1; $i <= 10e2; $i += $i * 2) {
    cmp_ok( Hailo->new( order => $i )->order, '==', $i, "The order is what we put in ($i)" );
}
