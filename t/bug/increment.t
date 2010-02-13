use 5.010;
use strict;
use warnings;
use Test::More tests => 16;

my %incs = (
    clever => sub {
        my ($hash, $k) = @_;
        $hash->{$k}++;
    },
    works => sub {
        my ($mem, $k) = @_;

        if (not exists $mem->{$k}) {
            $mem->{$k} = 1;
            return 0;
        } else {
            $mem->{$k} += 1;
            return $mem->{$k} - 1;
        }
    }
);

my @test = (
    [ 1, 0 ],
    [ 2, 1 ],
    [ 3, 2 ],
    [ 4, 3 ]
);

while (my ($subname, $sub) = each %incs) {
    my %hash;

    for my $test (@test) {
        my ($should_be, $should_get) = @$test;

        my $my_got = $sub->(\%hash, "akey");
        is($should_get, $my_got, "$subname: return value is '" . ($my_got // 'undef') . "', should be '" . ($should_get // 'undef') . "'");
        is($hash{akey}, $should_be, "$subname: Value after calling is '" . ($hash{akey} // 'undef') . "', should be '" . ($should_be // 'undef') . "'");
    }
}
