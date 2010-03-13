use strict;
use warnings;
use Test::More tests => 100;
use Hailo;

# this tests the retrieval of non-alphanumeric tokens

my $hailo = Hailo->new(
    brain => ':memory:',
);
my @lines = split /\n/, do { local $/ = undef; <DATA> };
$hailo->train(\@lines);

for (1..100) {
    my $reply = $hailo->reply(';');
    like($reply, qr/;/, 'Got semicolon');
}

__DATA__
Hello there; (foo) bar, baz :  3.14  quux,bla [hi].
Hello there foo.
What foo bar?
Foo; bar baz.
A b c; d.
