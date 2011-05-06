use 5.010;
use utf8;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::Tokenizer::Words;
use Time::HiRes qw<gettimeofday tv_interval>;

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
    {
        my $warn = '';
        local $SIG{__WARN__} = sub { $warn .= $_[0] };
        $t->($_, [ $_ ]) for "n" . "o" x 500;
        is($warn, '', "Didn't get Complex regular subexpression recursion limit (32766) exceeded");
    }

    my @want = ( qw[
        WoW 1
        foo 0
        Foo 0
        FoO 1
        fOO 1
        foO 1
        foO 1
        GumbyBRAIN 1
        gumbyBRAIN 1
        HoRRiBlE 1
        HoRRiBle 1
        hoRRiBle 1
    ] );

    while (my ($word, $should) = splice @want, 0, 2) {
        $t->($word, [ $should ? $word : lc $word ]);
    }

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
            [qw<" why hello there . « yes ». " foo is a bar>, '",', qw<e.g. bla ... yes>],
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
            [qw<on example.com ? yes>],
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
            'svn+ssh://svn.wikimedia.org/svnroot/mediawiki',
            [ qw< svn+ssh://svn.wikimedia.org/svnroot/mediawiki > ],
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
            [qw<anti-scientology demonstration in london ? hella-cool>],
            'Anti-scientology demonstration in london? Hella-cool.'
        ],
        [
            'This. compound-words are cool',
            [qw<this . compound-words are cool>],
            'This. Compound-words are cool.'
        ],
        [
            'Foo. Compound-word',
            [qw<foo .  compound-word>],
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
            'Cpanm is a true "religion."'
        ],
        [
            'cpanm is a true "anti-religion"',
            [qw<cpanm is a true " anti-religion ">],
            'Cpanm is a true "anti-religion."'
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
            [qw<.com bubble>],
            '.com bubble.'
        ],
        [
            'við vorum þar. í norður- eða vesturhlutanum',
            [qw<við vorum þar . í norður- eða vesturhlutanum>],
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
            "But..what about me? But...no.",
        ],
        [
            "For foo'345 'foo' bar",
            [qw<for foo ' 345 ' foo ' bar>],
            "For foo'345 'foo' bar.",
        ],
        [
            "loves2spooge",
            [qw<loves2spooge>],
            "Loves2spooge.",
        ],
        [
            'she´ll be doing it now',
            [qw<she´ll be doing it now>],
            'She´ll be doing it now.',
        ],
        [
            'CPAN upload: Crypt-Rijndael-MySQL-0.02 by SATOH',
            [qw<CPAN upload : Crypt-Rijndael-MySQL-0.02 by SATOH>],
            'CPAN upload: Crypt-Rijndael-MySQL-0.02 by SATOH.',
        ],
        [
            "I use a resolution of 800x600 on my computer",
            [qw<I use a resolution of 800x600 on my computer>],
            "I use a resolution of 800x600 on my computer.",
        ],
        [
            "WOAH 3D",
            [qw<WOAH 3D>],
            "WOAH 3D.",
        ],
        [
            "jarl sounds like yankee negro-lovers. britain was even into old men.",
            [qw<jarl sounds like yankee negro-lovers . britain was even into old men .>],
            "Jarl sounds like yankee negro-lovers. Britain was even into old men.",
        ],
        [
            "just look at http://beint.lýðræði.is does it turn tumi metrosexual",
            [qw<just look at http://beint.lýðræði.is does it turn tumi metrosexual>],
            "Just look at http://beint.lýðræði.is does it turn tumi metrosexual.",
        ],
        [
            'du: Invalid option --^',
            [qw<du : invalid option --^>],
            'Du: Invalid option --^',
        ],
        [
            '4.1GB downloaded, 95GB uploaded',
            [qw<4.1GB downloaded>, ',', qw<95GB uploaded>],
            '4.1GB downloaded, 95GB uploaded.',
        ],
        [
            'Use <http://google.com> as your homepage',
            [qw{use < http://google.com > as your homepage}],
            'Use <http://google.com> as your homepage.',
        ],
        [
            'Foo http://æðislegt.is,>>> bar',
            [qw{foo http://æðislegt.is}, ',>>>', 'bar'],
            'Foo http://æðislegt.is,>>> bar.',
        ],
        [
            'Foo http://æðislegt.is,$ bar',
            [qw<foo http://æðislegt.is>, ',$', 'bar'],
            'Foo http://æðislegt.is,$ bar.',
        ],
        [
            'http://google.is/search?q="stiklað+á+stóru"',
            [qw{http://google.is/search?q= " stiklað + á + stóru "}],
            'http://google.is/search?q="stiklað+á+stóru"',
        ],
        [
            'this is STARGΛ̊TE',
            [qw<this is STARGΛ̊TE>],
            'This is STARGΛ̊TE.',
        ],
        [
            'tumi.st@gmail.com tumi.st@gmail.com tumi.st@gmail.com',
            [qw<tumi.st@gmail.com tumi.st@gmail.com tumi.st@gmail.com>],
            'tumi.st@gmail.com tumi.st@gmail.com tumi.st@gmail.com',
        ],
        [
            'tumi@foo',
            [qw<tumi @ foo>],
            'tumi@foo',
        ],
        [
            'e.g. the river',
            [qw<e.g. the river>],
            'E.g. the river.',
        ],
        [
            'dong–licking is a really valuable book.',
            [qw<dong–licking is a really valuable book .>],
            'Dong–licking is a really valuable book.',
        ],
        [
            'taka úr sources.list',
            [qw<taka úr sources.list>],
            'Taka úr sources.list.',
        ],
        [
            'Huh? what? i mean what is your wife a...goer...eh? know what a dude last night...',
            [qw<huh ? what ? i mean what is your wife a ... goer ... eh ? know what a dude last night ...>],
            'Huh? What? I mean what is your wife a...goer...eh? Know what a dude last night...',
        ],
        [
            'neeeigh!',
            [qw<neeeigh !>],
            'Neeeigh!',
        ],
        [
            'neeeigh.',
            [qw<neeeigh .>],
            'Neeeigh.',
        ],
        [
            'odin-: foo-- # blah. odin-: yes',
            [qw<odin- : foo -->, '#', qw<blah . odin- : yes>],
            'Odin-: Foo-- # blah. Odin-: Yes.',
        ],
        [
            "struttin' that nigga",
            [qw<struttin' that nigga>],
            "Struttin' that nigga.",
        ],
        [
            '"maybe" and A better deal. "would" still need my coffee with tea.',
            [qw<" maybe " and A better deal . " would " still need my coffee with tea .>],
            '"Maybe" and A better deal. "Would" still need my coffee with tea.',
        ],
        [
            "This Acme::POE::Tree module is neat. Acme::POE::Tree",
            [qw<this Acme::POE::Tree module is neat . Acme::POE::Tree>],
            "This Acme::POE::Tree module is neat. Acme::POE::Tree",
        ],
        [
            "I use POE-Component-IRC",
            [qw<I use POE-Component-IRC>],
            "I use POE-Component-IRC.",
        ],
        [
            "You know, 4-3 equals 1",
            [qw<you know> ,',', qw<4-3 equals 1>],
            "You know, 4-3 equals 1.",
        ],
        [
            "moo-5 moo-5-moo moo_5",
            [qw<moo-5 moo-5-moo moo_5>],
            "Moo-5 moo-5-moo moo_5.",
        ],
        [
            "::Class Class:: ::Foo::Bar Foo::Bar:: Foo::Bar",
            [qw<::Class Class:: ::Foo::Bar Foo::Bar:: Foo::Bar>],
            "::Class Class:: ::Foo::Bar Foo::Bar:: Foo::Bar",
        ],
        [
            "It's as simple as C-u C-c C-t C-t t",
            [qw<it's as simple as C-u C-c C-t C-t t>],
            "It's as simple as C-u C-c C-t C-t t.",
        ],
        [
            "foo----------",
            [qw<foo ---------->],
            "foo----------",
        ],
        [
            "HE'S A NIGGER! HE'S A... wait",
            [qw<HE'S A NIGGER ! HE'S A ... wait>],
            "HE'S A NIGGER! HE'S A... wait.",
        ],
        [
            "I use\nPOE-Component-IRC",
            [qw<I use POE-Component-IRC>],
            "I use POE-Component-IRC.",
        ],
        [
            "I use POE-Component- \n IRC",
            [qw<I use POE-Component-IRC>],
            "I use POE-Component-IRC.",
        ],
        [
            "I wrote theres_no_place_like_home.ly. And then some.",
            [qw<I wrote theres_no_place_like_home.ly . and then some .>],
            "I wrote theres_no_place_like_home.ly. And then some.",
        ],
        [
            "The file is /hlagh/bar/foo.txt. Just read it.",
            [qw<the file is /hlagh/bar/foo.txt . just read it .>],
            "The file is /hlagh/bar/foo.txt. Just read it.",
        ],
        [
            "The file is C:\\hlagh\\bar\\foo.txt. Just read it.",
            [qw<the file is C:\\hlagh\\bar\\foo.txt . just read it .>],
            "The file is C:\\hlagh\\bar\\foo.txt. Just read it.",
        ],
        [
            "Tabs\ttabs\ttabs.",
            ['tabs', "\t", 'tabs', "\t", 'tabs', '.'],
            "Tabs\ttabs\ttabs.",
        ],
        [
            "2011-05-05 22:55 22:55Z 2011-05-05T22:55Z 2011-W18-4 2011-125 12:00±05:00 22:55 PM",
            [qw<2011-05-05 22:55 22:55Z 2011-05-05T22:55Z 2011-W18-4 2011-125 12:00±05:00>, '22:55 PM'],
            "2011-05-05 22:55 22:55Z 2011-05-05T22:55Z 2011-W18-4 2011-125 12:00±05:00 22:55 PM.",
        ],
        [
            '<@literal> oh hi < literal> what is going on?',
            [qw{<@literal> oh hi}, '< literal>', qw<what is going on ?>],
            '<@literal> oh hi < literal> what is going on?',
        ],
        [
            'It costs $.50, no, wait, it cost $2.50... or 50¢',
            [qw<it costs $.50>, ',', 'no', ',', 'wait', ',', qw<it cost $2.50 ... or 50¢>],
            'It costs $.50, no, wait, it cost $2.50... or 50¢.',
        ],
        [
            '10pt or 12em or 15cm',
            [qw<10pt or 12em or 15cm>],
            '10pt or 12em or 15cm.',
        ],
        [
            'failo is #1',
            [qw<failo is>, '#1'],
            'Failo is #1.',
        ],
    );

    my $toke = Hailo::Tokenizer::Words->new();

    for my $test (@tokens) {
        my @before = gettimeofday();
        my $tokens = $toke->make_tokens($test->[0]);
        my @after = gettimeofday();
        cmp_ok(tv_interval(\@before, \@after), '<', 1, 'Tokenizing in under <1 second');
        my $t;
        push @$t, $_->[1] for @$tokens;
        is_deeply($t, $test->[1], 'Tokens are correct');

        @before = gettimeofday();
        my $output = $toke->make_output($tokens);
        @after = gettimeofday();
        cmp_ok(tv_interval(\@before, \@after), '<', 1, 'Making output in <1 second');
        is_deeply($output, $test->[2], 'Output is correct');
    }

    done_testing();
};
