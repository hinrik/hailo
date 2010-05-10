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

plan tests => 5;

expect_run(
    command => "$^X bin/hailo -o 2 -b :memory:",
    prompt  => 'Hailo> ',
    quit    => '',
);

expect_send('foo', "Shouldn't learn from this");
expect_like(qr/I don't know enough/, "Don't get a reply");

expect_send('foo bar baz', 'Learn from the input');
expect_like(qr/Foo bar baz\./, 'Get a relevant reply');

# hailo(1) has no quit command. It only exits on EOF,
# so we'll close it manually
expect_handle->hard_close;
