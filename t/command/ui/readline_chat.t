use 5.010;
use strict;
use warnings;
use Test::Expect;
use Test::More tests => 5;
use Hailo;

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
