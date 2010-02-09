use 5.10.0;
use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 45;
use Test::Script;

# find lib -type f | perl -pe 's[^lib/][    ]; s[.pm$][]; s[/][::]g'
my @classes = qw(
  Hailo
  Hailo::Storage::SQLite
  Hailo::Storage::mysql
  Hailo::Storage::Pg
  Hailo::Storage::Perl
  Hailo::Storage::SQL
  Hailo::Role::Engine
  Hailo::Role::Generic
  Hailo::Role::UI
  Hailo::Role::Storage
  Hailo::Role::Tokenizer
  Hailo::UI::ReadLine
  Hailo::Engine::Default
  Hailo::Tokenizer::Characters
  Hailo::Tokenizer::Words
);

use_ok $_ for @classes;

{
    no strict 'refs';
    like(${"${_}::VERSION"}, qr/^[0-9.]+$/, "$_ has a \$VERSION that makes sense") for @classes;
}

{
    no strict 'refs';
    cmp_ok($Hailo::VERSION, '==', ${"${_}::VERSION"}, "$_\::VERSION matches \$Hailo::VERSION") for @classes[1 .. $#classes];
}

SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('script', 'hailo'));
};
