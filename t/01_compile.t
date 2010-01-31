use 5.10.0;
use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 16;
use Test::Script;

# find lib -type f|perl -pe 's/lib.//; s[/][::]g; s[.pm][]; s[^]{use ok q[}; s[$]{];}'|sort
use_ok q[Hailo];
use_ok q[Hailo::Engine::Default];
use_ok q[Hailo::Role::Engine];
use_ok q[Hailo::Role::Generic];
use_ok q[Hailo::Role::Storage];
use_ok q[Hailo::Role::Tokenizer];
use_ok q[Hailo::Role::UI];
use_ok q[Hailo::Storage::mysql];
use_ok q[Hailo::Storage::Perl];
use_ok q[Hailo::Storage::Pg];
use_ok q[Hailo::Storage::SQL];
use_ok q[Hailo::Storage::SQLite];
use_ok q[Hailo::Tokenizer::Characters];
use_ok q[Hailo::Tokenizer::Words];
use_ok q[Hailo::UI::ReadLine];

SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('script', 'hailo'));
};
