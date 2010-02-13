use 5.010;
use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::Tokenizer::Words;

binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

subtest make_tokens => sub {

    my $t = sub {
        my ($str, $tokens) = @_;

        is_deeply(
            [ Hailo::Tokenizer::Words::make_tokens(Hailo::Tokenizer::Words->new, $str) ],
            $tokens,
            "make_tokens: <<$str>> ==> " . (join ' ', map { qq[<<$_>>] } @$tokens) . ""
        );
    };

    for my $chr (map { chr } 11 .. 200) {
        $t->($chr, [ $chr ]);
    }

    # $t->("", [ '' ]);
    $t->("", undef);
    $t->("foo bar", [ 'foo', ' ', 'bar' ]);
    $t->("Æ", [ 'Æ' ]);

    # Apostrophe
    #use Data::Dump 'dump';
    #say dump Hailo::Tokenizer::Words::make_tokens(undef, "'foo' 'bar'");
    $t->("'foo' 'bar'", [ ("'", "foo", "'", " ", "'", "bar", "'") ]);
    $t->("’foo’ ’bar’", [ ("’", "foo", "’", " ", "’", "bar", "’") ]);

    done_testing();
};

subtest make_output => sub {
    my @tokens = (
        [
            ' " why hello there. «yes». "foo is a bar", e.g. bla ... yes',
            [
                ' ', '"', ' ', 'why', ' ', 'hello', ' ', 'there', '.', ' ', '«',
                'yes', '»', '.', ' ', '"', 'foo', ' ', 'is', ' ', 'a', ' ',
                'bar', '"', ',', ' ', 'e.g', '.', ' ', 'bla', ' ', '.',
                '.', '.', ' ', 'yes',
            ],
            '" Why hello there. «Yes». "Foo is a bar", e.g. bla ... yes.',
        ],
        [
            "someone: how're you?",
            ['someone', ':', ' ', "how're", ' ', 'you', '?'],
            "Someone: How're you?",
        ],
        [
            'what?! well...',
            ['what', '?', '!', ' ', 'well', '.', '.', '.'],
            'What?! Well...',
        ],
        [
            'hello. you: what are you doing?',
            [
                'hello', '.', ' ', 'you', ':', ' ','what', ' ', 'are', ' ', 'you',
                ' ', 'doing', '?',
            ],
            'Hello. You: What are you doing?',
        ],
        [
            'foo: foo: foo: what are you doing?',
            [
                'foo', ':', ' ', 'foo', ':', ' ', 'foo', ':', ' ','what', ' ',
                'are', ' ', 'you', ' ', 'doing', '?',
            ],
            'Foo: Foo: Foo: What are you doing?',
        ],
        [
            "I'm talking about this key:value thing",
            [
                "i'm", ' ', 'talking', ' ', 'about', ' ', 'this', ' ', 'key',
                ':', 'value', ' ', 'thing',
            ],
            "I'm talking about this key:value thing."
        ],
        [
            "what? but that's impossible",
            [
                'what', '?', ' ', 'but', ' ', "that's", ' ', 'impossible',
            ],
            "What? But that's impossible.",
        ],
        [
            'on example.com? yes',
            [
                'on', ' ', 'example.com', '?', ' ', 'yes',
            ],
            "On example.com? Yes.",
        ],
        [
            "sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
            [
                'sá', ' ', "'", "'", 'karlkyns', "'", "'", ' ', 'aðili', ' ',
                'í', ' ', '[', '[', 'hjónaband', ']', ']', 'i', ' ',
                'tveggja', ' ', 'lesbía', '?',
            ],
            "Sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
        ],
    );

    my $toke = Hailo::Tokenizer::Words->new();

    for my $test (@tokens) {
        my $tokens = [$toke->make_tokens($test->[0])];
        is_deeply($tokens, $test->[1], 'Tokens are correct');
        my $output = $toke->make_output($tokens);
        is_deeply($output, $test->[2], 'Output is correct');
    }

    done_testing();
};
