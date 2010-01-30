use 5.10.0;
use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 8;
use Test::Script;
use_ok 'Hailo';
use_ok 'Hailo::Role::Storage';
use_ok 'Hailo::Role::Tokenizer';
use_ok 'Hailo::Storage::Perl';
use_ok 'Hailo::Storage::SQLite';
use_ok 'Hailo::Tokenizer::Words';
use_ok 'Hailo::Tokenizer::Characters';
SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('script', 'hailo'));
};
