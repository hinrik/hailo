use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 4;
use Test::Script;
use_ok 'Hal';
use_ok 'Hal::Storage::Perl';
use_ok 'Hal::Tokenizer::Generic';
script_compiles_ok(catfile('script', 'hal'));
