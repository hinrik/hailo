use 5.10.0;
use strict;
use warnings;
use Hailo;
use Test::More tests => 36;

my @give = (undef, 1 .. 4);

my %incs = (
    clever => sub {
        my ($hash, $k) = @_;
        $hash->{$k}++;
    },
    not_clever => sub {
        my ($hash, $k) = @_;
        no warnings 'uninitialized';
        my $now = $hash->{$k};
        my $after = defined $now ? $now + 1 : int $now;
        $hash->{$k} = $after;
        return $after;
    },
    normal => sub {
        my ($hash, $k) = @_;

        if (exists $hash->{$k}) {
            $hash->{$k}++;
            return $hash->{$k};
        } else {
            $hash->{$k} = 0;
            return 0;
        }
    },
);

while (my ($k, $v) = each %incs) {
    my %hash;

    for (my $i = 0; $i <= @give; $i++) {
        my $ret = $v->(\%hash, "akey");
        pass("Return value is $ret");
        cmp_ok(
            $ret,
            '==',
            $i,
            "Incrementing with $k went as expected"
        );
    }
}
