use 5.10.0;
use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::Tokenizer::Characters;
use Data::Random qw(:all);

binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

subtest make_tokens => sub {
    my $t = sub {
        my ($str, $tokens) = @_;

        is_deeply(
            [ Hailo::Tokenizer::Characters::make_tokens(undef, $str) ],
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

        is_deeply(
            [ Hailo::Tokenizer::Characters::make_output(undef, Hailo::Tokenizer::Characters::make_tokens(undef, $str)) ],
            $output,
            "make_output: <<$str>> ==> " . (join ' ', map { qq[<<$_>>] } @$output) . ""
        );
    };

    for my $chr (map { chr } 1 .. 2**12) {
        #$t->($chr, [ $chr ]);
    }

    my @random_chars = rand_chars( set => 'all', min => 5, max => 8 );
    my @random_words = rand_words( size => 10 );

    $t->($_, [ join '', split //, $_ ]) for @random_words;
    $t->($_, [ join '', split //, $_ ]) for @random_chars;

    done_testing();
};
