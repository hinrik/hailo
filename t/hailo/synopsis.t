use 5.010;
use strict;
use warnings;
use Test::More;
plan skip_all => "Test::Synopsis required for testing SYNOPSIS" unless eval { require Test::Synopsis };
plan tests => 1;

my ($synopsis) = Test::Synopsis::extract_synopsis('lib/Hailo.pm');
$synopsis =~ s/^.*?(?=\s+use)//s;

local $@;
eval <<'SYNOPSIS';
open my $filehandle, '<', __FILE__;
chdir 't/lib/Hailo/Test';
$synopsis
SYNOPSIS

is($@, '', "No errors in SYNOPSIS");
