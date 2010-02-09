use 5.10.0;
use strict;
use warnings;
use Hailo;
use Test::More tests => 55;

my $hailo = Hailo->new(
    storage_class => "SQLite",
    brain_resource => ':memory:',
);

while (<DATA>) {
    chomp;
    $hailo->learn($_);
}
SKIP: {
    skip "This test needs to be refactored to reflect recent changes", 55;
    for (1 .. 5) {
        for (1 .. 5) {
            my $reply = $hailo->reply("badger");
            like($reply,
                qr/^Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger! Badger(?:\.|!|! )$/,
                "Badger badger badger badger badger badger badger badger badger badger badger badger");
            pass("Mushroom Mushroom");
        }
        pass("A big ol' snake - snake a snake oh it's a snake");
    }
}

__DATA__
badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger!
badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger! badger!
