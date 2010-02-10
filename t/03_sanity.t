use 5.10.0;
use strict;
use warnings;
use Hailo;
use Test::More tests => 8;

for my $storage (qw(Perl PerlFlat CHI SQLite)) {
    my $hailo = Hailo->new(
        storage_class => $storage,
        ($storage eq 'SQLite'
            ? (brain_resource => ':memory:')
            : ()
        ),
    );
    my $string = "Congress\t shall\t make\t no\t law.";
    my $reply  = $string;
    $reply     =~ tr/\t//d;

    $hailo->learn($string);
    is($hailo->reply('make'), $reply, "$storage: Learned string correctly");
    is($hailo->reply('respecting'), undef, "$storage: Hasn't learned this word yet");
}
