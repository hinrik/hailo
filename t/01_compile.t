use 5.010;
use strict;
use warnings;
use Class::MOP;
use File::Spec::Functions 'catfile';
use Test::More;
use Test::Script;

# find lib -type f | perl -pe 's[^lib/][    ]; s[.pm$][]; s[/][::]g'
my @classes = qw(
    Hailo
    Hailo::Storage::Mixin::DBD
    Hailo::Storage::Mixin::CHI
    Hailo::Storage::Mixin::Hash::Flat
    Hailo::Storage::Mixin::Hash
    Hailo::Storage::Mixin::Storable
    Hailo::Storage::CHI::BerkeleyDB
    Hailo::Storage::CHI::File
    Hailo::Storage::CHI::Memory
    Hailo::Storage::Perl
    Hailo::Storage::Perl::Flat
    Hailo::Storage::DBD::SQLite
    Hailo::Storage::DBD::mysql
    Hailo::Storage::DBD::Pg
    Hailo::Role::Generic
    Hailo::Role::UI
    Hailo::Role::Storage
    Hailo::Role::Log
    Hailo::Role::Tokenizer
    Hailo::UI::ReadLine
    Hailo::Tokenizer::Words
    Hailo::Tokenizer::Chars
);

plan tests => scalar(@classes) * 2 + 1;

my $i = 1; for (@classes) {
  SKIP: {
    eval { Class::MOP::load_class($_) };

    skip "Couldn't compile optional dependency $_", 2 if $@ =~ /Couldn't load class/;

    no strict 'refs';
    like(${"${_}::VERSION"}, qr/^[0-9.]+$/, "$_ has a \$VERSION that makes sense");

    cmp_ok(
        ${"${_}::VERSION"},
        '==',
        $Hailo::VERSION,
        qq[$_\::VERSION matches \$Hailo::VERSION. If not use perl-reversion --current ${"${_}::VERSION"} -bump]
    );
  }
    $i++;
}

SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('script', 'hailo'));
};
