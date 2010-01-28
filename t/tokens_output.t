use strict;
use warnings;
use utf8;
use Test::More;
use Hailo::Tokenizer::Words;

binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

my @tokens = (
    [
        ' " why hello there. «yes». "foo is a bar", e.g. bla ... yes',
        [
            ' ', '"', ' ', 'why', ' ', 'hello', ' ', 'there', '.', ' ', '«',
            'yes', '»', '.', ' ', '"', 'foo', ' ', 'is', ' ', 'a', ' ',
            'bar', '"', ',', ' ', 'e', '.', 'g', '.', ' ', 'bla', ' ', '.',
            '.', '.', ' ', 'yes',
        ],
        ' " Why hello there. «Yes». "Foo is a bar", e.g. bla ... yes.',
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
            'foo', ':', ' ', 'foo', ':', ' ', 'foo', ':', ' ','what', ' ', 'are', ' ', 'you',
            ' ', 'doing', '?',
        ],
        'Foo: Foo: Foo: What are you doing?',
    ],
);

plan tests => 2 * scalar @tokens;

my $toke = Hailo::Tokenizer::Words->new();

for my $test (@tokens) {
    my $tokens = [$toke->make_tokens($test->[0])];
    is_deeply($tokens, $test->[1], 'Tokens are correct');
    my $output = $toke->make_output(@$tokens);
    is_deeply($output, $test->[2], 'Output is correct');
}
