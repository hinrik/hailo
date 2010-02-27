use strict;
use Any::Moose;
use Test::More tests => 1;

my $m = any_moose();
diag("Testing with $^X $] using $m for Moose");
pass("Token test");
