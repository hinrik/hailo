use 5.10.0;
use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 48;
use Test::Script;

# find lib -type f | perl -pe 's[^lib/][    ]; s[.pm$][]; s[/][::]g'
my @classes = qw(
  Hailo
  Hailo::Storage::DBD::SQLite
  Hailo::Storage::DBD::mysql
  Hailo::Storage::DBD::Pg
  Hailo::Storage::DBD
  Hailo::Storage::Perl
  Hailo::Storage::PerlFlat
  Hailo::Role::Engine
  Hailo::Role::Generic
  Hailo::Role::UI
  Hailo::Role::Storage
  Hailo::Role::Tokenizer
  Hailo::UI::ReadLine
  Hailo::Engine::Default
  Hailo::Tokenizer::Chars
  Hailo::Tokenizer::Words
);

use_ok $_ for @classes;

{
    no strict 'refs';
    like(${"${_}::VERSION"}, qr/^[0-9.]+$/, "$_ has a \$VERSION that makes sense") for @classes;
}

{
    no strict 'refs';
    cmp_ok(
        ${"${_}::VERSION"},
        '==',
        $Hailo::VERSION,
        qq[$_\::VERSION matches \$Hailo::VERSION. If not use perl-reversion --current ${"${_}::VERSION"} -bump]
    ) for @classes[1 .. $#classes];
}

SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('script', 'hailo'));
};
