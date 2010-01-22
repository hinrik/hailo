use strict;
use warnings;
use Hal;
use Test::More tests => 2;

my $hal = Hal->new(storage => 'Perl');
my $string = 'Congress shall make no law';

$hal->learn($string);
is($hal->reply('make'), $string, 'Learned string correctly');
is($hal->reply('respecting'), undef, "Hasn't learned this word yet");
