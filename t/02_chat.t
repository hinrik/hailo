use strict;
use warnings;
use Hal;
use Test::More tests => 4;

for my $storage (qw(Perl SQLite)) {
    my $hal = Hal->new_with_options(
        storage => $storage,
        ($storage eq 'SQLite'
            ? (file => ':memory:')
            : ()
        ),
    );
    my $string = 'Congress shall make no law';

    $hal->learn($string);
    is($hal->reply('make'), $string, 'Learned string correctly');
    is($hal->reply('respecting'), undef, "Hasn't learned this word yet");
}
