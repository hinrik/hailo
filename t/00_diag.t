use 5.010;
use strict;
use Any::Moose;
use Test::More tests => 1;
use Hailo;

my $version = $Hailo::VERSION // 'dev-git';

my $m = any_moose();
diag("Testing Hailo $version with $^X $] using $m for Moose");
pass("Token test");
