use strict;
use warnings;
use Test::More tests => 4;
use Hailo;

my $hailo = Hailo->new(brain_resource => ':memory:');

while (<DATA>) {
    chomp;
    $hailo->learn($_);
}

is($hailo->reply("bar"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");
is($hailo->reply("zar"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");
is($hailo->reply("nar"), undef, "TODO: Hailo doesn't learn from tokenize(str) > order input yet");

my %reply;
for (1 .. 50) {
    $reply{ $hailo->reply("xxyy") } = 1;
}

is_deeply([ sort keys %reply ], [ map { "Xxyy yyxx $_." } sort qw(bleh bluh brah blib) ], "Make sure we get every possible reply");

__DATA__
foo bar
foo zar
foo nar
xxyy yyxx bleh
xxyy yyxx bluh
xxyy yyxx brah
xxyy yyxx blib
