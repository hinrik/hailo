use 5.010;
use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::Tokenizer::Chars;
use Data::Random qw(:all);

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

    my @random_chars = rand_chars( set => 'all', min => 5, max => 8 );
    my @random_words = rand_words( size => 10 );

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

    my @random_chars = rand_chars( set => 'all', min => 5, max => 8 );
    my @random_words = rand_words( size => 10 );

    $t->($_, join '', split //, $_) for @random_words;
    $t->($_, join '', split //, $_) for @random_chars;

    done_testing();
};
