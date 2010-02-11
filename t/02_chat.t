use 5.10.0;
use strict;
use warnings;
use Hailo;
use Test::More tests => 6;

for my $storage (qw(Perl Perl::Flat DBD::SQLite)) {
    my $hailo = Hailo->new(
        storage_class => $storage,
        ($storage eq 'SQLite'
            ? (brain_resource => ':memory:')
            : ()
        ),
    );
    my $string = 'Congress shall make no law.';

    $hailo->learn($string);
    is($hailo->reply('make'), $string, "$storage: Learned string correctly");
    is($hailo->reply('respecting'), undef, "$storage: Hasn't learned this word yet");
}
