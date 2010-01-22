use utf8;
use Test::More tests => 1;
use Hal::Tokenizer::Generic;

binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

subtest make_tokens => sub {

    my $t = sub {
        my ($str, $tokens) = @_;

        is_deeply(
            [ Hal::Tokenizer::Generic::make_tokens(undef, $str) ],
            $tokens,
            "make_tokens: <<$str>> ==> <<" . (join ' ', map { qq['$_'] } @$tokens) . ">>"
        );
    };

    for my $chr (map { chr } 11 .. 200) {
        $t->($chr, [ $chr ]);
    }

    # $t->("", [ '' ]);
    $t->("", undef);
    $t->("foo bar", [ 'foo', ' ', 'bar' ]);
    $t->("Æ", [ 'Æ' ]);

    done_testing();
};
