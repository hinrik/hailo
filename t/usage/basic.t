use 5.10.0;
use strict;
use warnings;
use Test::More tests => 4;
use Hailo;

my $hailo = Hailo->new(brain_resource => ':memory:');

while (<DATA>) {
    $hailo->learn($_);
}

is($hailo->reply("bar"), "Foo bar.", "There can be only one");
is($hailo->reply("zar"), "Foo zar.", "There can be only one");
is($hailo->reply("nar"), "Foo nar.", "There can be only one");

my %reply;
for (1 .. 10000) {
    $reply{ $hailo->reply("foo") } = 1;
}

is_deeply([ sort keys %reply ], [ "Foo bar.", "Foo nar.", "Foo zar." ], "Make sure we get every possible reply");

__DATA__
foo bar
foo zar
foo nar
