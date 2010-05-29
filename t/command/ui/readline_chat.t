use 5.010;
use strict;
use warnings;
use Hailo;
use Test::More;
BEGIN {
    # This roundabout way of doing things is due to:
    ## Can't locate object method "hard_close" via package
    ## "expect_handle" (perhaps you forgot to load "expect_handle"?)
    # If I just do C<eval 'use Test::Expect'> or C<eval { require
    # Test::Expect; Test::Expect->import }>. Too lazy to find out why
    eval 'require Test::Expect';
    plan skip_all => "Test::Expect required for testing readline chat" if $@;
}
use Test::Expect;

plan tests => 25;

expect_run(
    command => "$^X -Ilib bin/hailo -o 2 -b :memory:",
    prompt  => 'Hailo> ',
    quit    => '.quit',
);

expect_send('foo', "Shouldn't learn from this");
expect_like(qr/I don\'t know enough/, "Don't get a reply");

expect_send('foo bar baz', 'Learn from the input');
expect_like(qr/Foo bar baz\./, 'Get a relevant reply');

expect_send('.stats', 'Ask for statistics');
expect_like(qr/\(3, 2, 2, 2\)/, "Get statistics");

expect_send('.learn "Moo Moo farm."', 'Learn the Moo Moo farm');
expect_like(qr/\(\)/, "Learn a string");

expect_send('.stats', 'Ask for statistics');
expect_like(qr/\(6, 5, 5, 5\)/, "Get statistics");

expect_send('.learn_reply "Moo Moo farm"', '.learn_reply');
expect_like(qr/".*moo.*\."/i, "learn and reply");

expect_send('.stats', 'Ask for statistics');
expect_like(qr/\(6, 5, 5, 6\)/, "Get statistics");

expect_send('.learn_reply hello', 'A bareword');
expect_like(qr/Failed on.*undef input/, "Failed on a bareword");

expect_send('.stats', 'Ask for statistics');
expect_like(qr/\(6, 5, 5, 6\)/, "Get statistics");

expect_send('.train "' . __FILE__ . '"', 'Train from this file: ' . __FILE__);
expect_like(qr/Trained from/, "successful training");

expect_send('.stats', 'Ask for statistics');
expect_like(qr/\(169, 269, 302, 316\)/, "Get statistics");

expect_send('.help', 'Ask for some help');
expect_like(qr/The commands are just method calls/, "Get help from ReadLine");


