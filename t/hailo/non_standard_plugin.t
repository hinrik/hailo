package main;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Hailo;

plan(skip_all => "A `Issuing rollback() due to DESTROY without explicit disconnect()' bug in Hailo");
plan(tests => 2);

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

