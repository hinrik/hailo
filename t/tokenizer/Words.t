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

        my $toke = Hailo::Tokenizer::Words->new();
        my $parsed = $toke->make_tokens($str);
        my $tok;
        push @$tok, $_->[1] for @$parsed;
        is_deeply(
            $tok,
            $tokens,
            "make_tokens: <<$str>> ==> " . (join ' ', map { qq[<<$_>>] } @$tokens) . ""
        );
    };

    for my $chr (map { chr } 11 .. 200) {
        next if $chr =~ /^\s$/;
        $t->($chr, [ $chr ]);
    }

    $t->("foo bar", [ qw<foo bar> ]);
    $t->("Æ", [ 'Æ' ]);

    # Words like WoW and other odd things that change capitalization
    # mid-way should retain their capitalization.
    $t->("I hate WoW.", [ qw< I hate WoW . > ]);

    # Preserve mixed capitalization
    $t->("GumbyBRAIN", [ qw< GumbyBRAIN > ]);
    $t->("\"GumbyBRAIN\"", [ qw< " GumbyBRAIN " > ]);
    $t->("HoRRiBlE", [ qw< HoRRiBlE > ]);
    $t->("HoRRiBle", [ qw< HoRRiBle > ]);
    $t->("hoRRiBle", [ qw< hoRRiBle > ]);

    # Similarly we should preserve capitalization on words split by '
    # and other \W characters
    $t->("I FYIQ'ed that job.", [ qw< I FYIQ'ed that job . > ]);
    $t->("That guy was KIA'd.", [ qw< that guy was KIA'd . > ]);

    done_testing();
};

subtest make_output => sub {
    my @tokens = (
        [
            ' " why hello there. «yes». "foo is a bar", e.g. bla ... yes',
            [qw<" why hello there . « yes ». " foo is a bar>, '",', qw<e . g . bla ... yes>],
            '" Why hello there. «Yes». "Foo is a bar", e.g. bla ... yes.',
        ],
        [
            "someone: how're you?",
            [qw<someone : how're you ?>],
            "Someone: How're you?",
        ],
        [
            'what?! well...',
            [qw<what ?! well ...>],
            'What?! Well...',
        ],
        [
            'hello. you: what are you doing?',
            [qw<hello . you : what are you doing ?>],
            'Hello. You: What are you doing?',
        ],
        [
            'foo: foo: foo: what are you doing?',
            [qw<foo : foo : foo : what are you doing ?>],
            'Foo: Foo: Foo: What are you doing?',
        ],
        [
            "I'm talking about this key:value thing",
            [qw<i'm talking about this key : value thing>],
            "I'm talking about this key:value thing."
        ],
        [
            "what? but that's impossible",
            [qw<what ? but that's impossible>],
            "What? But that's impossible.",
        ],
        [
            'on example.com? yes',
            [qw<on example . com ? yes>],
            "On example.com? Yes.",
        ],
        [
            'pi is 3.14, well, almost',
            [qw<pi is 3.14>, ',', 'well', ',', 'almost'],
            "Pi is 3.14, well, almost.",
        ],
        [
            'foo 0.40 bar or .40 bar bla 0,40 foo ,40',
            [qw<foo 0.40 bar or .40 bar bla>, '0,40', 'foo', ',40'],
            'Foo 0.40 bar or .40 bar bla 0,40 foo ,40.',
        ],
        [
            "sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
            [qw<sá '' karlkyns '' aðili í [[ hjónaband ]] i tveggja lesbía ?>],
            "Sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
        ],
        [
            "you mean i've got 3,14? yes",
            [qw<you mean i've got>, '3,14', '?', 'yes'],
            "You mean I've got 3,14? Yes.",
        ],
        [
            'Pretty girl like her "peak". oh and you’re touching yourself',
            [qw<pretty girl like her " peak ". oh and you’re touching yourself>],
            'Pretty girl like her "peak". Oh and you’re touching yourself.',
        ],
        [
            'http://foo.BAR/bAz',
            [qw<http://foo.BAR/bAz>],
            'http://foo.BAR/bAz',
        ],
        [
            'http://www.example.com/some/path?funny**!(),,:;@=&=',
            [ 'http://www.example.com/some/path?funny**!(),,:;@=&=' ],
            'http://www.example.com/some/path?funny**!(),,:;@=&=',
        ],
        [
            # TODO: Support + in URIs
            'svn+ssh://svn.wikimedia.org/svnroot/mediawiki',
            [ qw< svn + ssh :// svn . wikimedia . org / svnroot / mediawiki > ],
            'svn+ssh://svn.wikimedia.org/svnroot/mediawiki',
        ],
        [
            "foo bar baz. i said i'll do this",
            [qw<foo bar baz . i said i'll do this>],
            "Foo bar baz. I said I'll do this.",
        ],
        [
            'talking about i&34324 yes',
            [qw<talking about i & 34324 yes>],
            'Talking about i&34324 yes.'
        ],
        [
            'talking about i',
            [qw<talking about i>],
            'Talking about i.'
        ],
        [
            'none, as most animals do, I love conservapedia.',
            ['none', ',', qw<as most animals do>, ',', qw<I love conservapedia .>],
            'None, as most animals do, I love conservapedia.'
        ],
        [
            'hm...',
            [qw<hm ...>],
            'Hm...'
        ],
        [
            'anti-scientology demonstration in london? hella-cool',
            [qw<anti - scientology demonstration in london ? hella - cool>],
            'Anti-scientology demonstration in london? Hella-cool.'
        ],
        [
            'This. compound-words are cool',
            [qw<this . compound - words are cool>],
            'This. Compound-words are cool.'
        ],
        [
            'Foo. Compound-word',
            [qw<foo .  compound - word>],
            'Foo. Compound-word.'
        ],
        [
            'one',
            [qw<one>],
            'One.'
        ],
        [
            'cpanm is a true "religion"',
            [qw<cpanm is a true " religion ">],
            'Cpanm is a true "religion".'
        ],
        [
            'cpanm is a true "anti-religion"',
            [qw<cpanm is a true " anti - religion ">],
            'Cpanm is a true "anti-religion".'
        ],
        [
            'Maps to weekends/holidays',
            [qw<maps to weekends / holidays>],
            'Maps to weekends/holidays.'
        ],
        [
            's/foo/bar',
            [qw<s / foo / bar>],
            's/foo/bar'
        ],
        [
            's/foo/bar/',
            [qw<s / foo / bar />],
            's/foo/bar/'
        ],
        [
            'Where did I go? http://foo.bar/',
            [qw<where did I go ? http://foo.bar/>],
            'Where did I go? http://foo.bar/'
        ],
        [
            'What did I do? s/foo/bar/',
            [qw<what did I do ? s / foo / bar />],
            'What did I do? s/foo/bar/'
        ],
        [
            'I called foo() and foo(bar)',
            [qw<I called foo () and foo ( bar )>],
            'I called foo() and foo(bar)'
        ],
        [
            'foo() is a function',
            [qw<foo () is a function>],
            'foo() is a function.'
        ],
        [
            'the symbol : and the symbol /',
            [qw<the symbol : and the symbol />],
            'The symbol : and the symbol /'
        ],
        [
            '.com bubble',
            [qw<. com bubble>],
            '.com bubble.'
        ],
        [
            'við vorum þar. í norður- eða vesturhlutanum',
            [qw<við vorum þar . í norður - eða vesturhlutanum>],
            'Við vorum þar. Í norður- eða vesturhlutanum.'
        ],
        [
            "i'm talking about -postfix. yeah",
            [qw<i'm talking about - postfix . yeah>],
            "I'm talking about -postfix. yeah.",
        ],
        [
            "But..what about me? but...no",
            [qw<but .. what about me ? but ... no>],
            "But..what about me? But...no",
        ],
        [
            "For foo'345",
            [qw<for foo ' 345>],
            "For foo'345",
        ],
        [
            "loves2spooge",
            [qw<loves2spooge>],
            "Loves2spooge.",
        ],
    );

    my $toke = Hailo::Tokenizer::Words->new();

    for my $test (@tokens) {
        my $tokens = $toke->make_tokens($test->[0]);
        my $t;
        push @$t, $_->[1] for @$tokens;
        is_deeply($t, $test->[1], 'Tokens are correct');
        my $output = $toke->make_output($tokens);
        is_deeply($output, $test->[2], 'Output is correct');
    }

    done_testing();
};
