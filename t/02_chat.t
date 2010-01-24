use strict;
use warnings;
use Hailo;
use Test::More tests => 4;

for my $storage (qw(Perl SQLite)) {
    my $hailo = Hailo->new_with_options(
        storage => $storage,
        ($storage eq 'SQLite'
            ? (file => ':memory:')
            : ()
        ),
    );
    my $string = 'Congress shall make no law';

    $hailo->learn($string);
    is($hailo->reply('make'), $string, 'Learned string correctly');
    is($hailo->reply('respecting'), undef, "Hasn't learned this word yet");
}
