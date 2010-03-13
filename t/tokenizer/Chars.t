use 5.010;
use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::Tokenizer::Chars;

binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

my $toke = Hailo::Tokenizer::Chars->new();

subtest make_tokens => sub {
    my $t = sub {
        my ($str, $tokens) = @_;

        my $parsed = $toke->make_tokens($str);
        my $tok;
        push @$tok, $_->[1] for @$parsed;
        is_deeply(
            $tok,
            $tokens,
            "make_tokens: <<$str>> ==> " . (join ' ', map { qq[<<$_>>] } @$tokens) . ""
        );
    };

    for my $chr (map { chr } 1 .. 2**12) {
        $t->($chr, [ split //, $chr ]);
    }

    my @chr = map { chr } 50..120;
    my @random_chars = map { $chr[rand @chr] } 1 .. 30;
    my @wrd = qw<
                    Hailo is a fast and lightweight markov engine
                    intended to replace AI::MegaHAL. It has a Mouse
                    (or Moose) based core with pluggable storage and
                    tokenizer backends.
                >;
    my @random_words = map { $chr[rand @chr] } 1 .. 30;

    $t->($_, [ split //, $_ ]) for @random_words;
    $t->($_, [ split //, $_ ]) for @random_chars;

    done_testing();
};

subtest make_output => sub {
    my $t = sub {
        my ($str, $output) = @_;

        my $tokens = $toke->make_tokens($str);
        my $out = $toke->make_output($tokens);
        is_deeply(
            $out,
            $output,
            "make_output: <<$str>> ==> " . (join ' ', map { qq[<<$_>>] } $output),
        );
    };

    for my $chr (map { chr } 1 .. 2**12) {
        #$t->($chr, $chr);
    }

    my @chr = map { chr } 50..120;
    my @random_chars = map { $chr[rand @chr] } 1 .. 30;
    my @wrd = qw<
                    Hailo is a fast and lightweight markov engine
                    intended to replace AI::MegaHAL. It has a Mouse
                    (or Moose) based core with pluggable storage and
                    tokenizer backends.
                >;
    my @random_words = map { $chr[rand @chr] } 1 .. 30;

    $t->($_, join '', split //, $_) for @random_words;
    $t->($_, join '', split //, $_) for @random_chars;

    done_testing();
};
