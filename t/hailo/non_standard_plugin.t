package main;
use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 2;
use Hailo;

{
    local $@;
    eval {
        my $hailo = Hailo->new(
            tokenizer_class => 'Hailo::Test::Tokenizer',
        );
        $hailo->learn("blah blah");
        ok($hailo->reply(), "got reply");
    };
    like($@, qr/Couldn't find.*Hailo::Test::Tokenizer/, "Non-standard plugin without +");
}

{

    my $hailo = Hailo->new(
        tokenizer_class => '+Hailo::Test::Tokenizer',
    );
    $hailo->learn("blah blah");
    ok($hailo->reply(), "got reply");
}

