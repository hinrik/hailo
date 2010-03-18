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
    Hailo::Storage::DBD
    Hailo::Storage::DBD::SQLite
    Hailo::Storage::DBD::mysql
    Hailo::Storage::DBD::Pg
    Hailo::Role::Arguments
    Hailo::Role::UI
    Hailo::Role::Storage
    Hailo::Role::Tokenizer
    Hailo::UI::ReadLine
    Hailo::Tokenizer::Words
    Hailo::Tokenizer::Chars
);

plan tests => scalar(@classes) * 3 + 1;

my $i = 1; for (@classes) {
  SKIP: {
    eval { Class::MOP::load_class($_) };

    skip "Couldn't compile optional dependency $_", 1 if $@ =~ /Couldn't load class/;
    pass("Loaded class $_");
  }
}


SKIP: {
    no strict 'refs';

    unless (defined ${"Hailo::VERSION"}) {
        skip "Can't test \$VERSION from a Git checkout", 2 * scalar(@classes);
    }

    my $j = 1; for (@classes) {
        like(${"${_}::VERSION"}, qr/^[0-9.]+$/, "$_ has a \$VERSION that makes sense");

        cmp_ok(
            ${"${_}::VERSION"},
            'eq',
            $Hailo::VERSION,
            qq[$_\::VERSION matches \$Hailo::VERSION. If not use perl-reversion --current ${"${_}::VERSION"} -bump]
        );
    }
}

SKIP: {
    skip "There's no blib", 1 unless -d "blib" and -f catfile qw(blib script hailo);
    script_compiles_ok(catfile('bin', 'hailo'));
};
