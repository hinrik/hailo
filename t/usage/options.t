use 5.010;
use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Test::More tests => 36;
use Test::Exception;
use Test::Output;
use Test::Exit;
use Hailo;

$SIG{__WARN__} = sub {
    print STDERR @_ if $_[0] !~ m/(?:^Issuing rollback|for database handle being DESTROY)/
};

# --version
stdout_like(
    sub {
        never_exits_ok( sub { Hailo->new( print_version => 1)->run }, "exiting exits")
    },
    qr/^hailo [0-9.]+$/,
    "Hailo prints its version",
);

# Invalid train file
dies_ok { Hailo->new( train_file => "/this-does-not-exist/$$" )->run }  "Calling Hailo with an invalid training file";
# Valid train file
lives_ok { Hailo->new( train_file => __FILE__, print_progress => 0 )->run }  "Calling Hailo with a valid training file";

# learn_str
lives_ok { Hailo->new( learn_str => "foo" )->run } "Hailo can learn from a string";

# learn/reply
is( sub {
        my $hailo = Hailo->new;
        $hailo->learn("hello there good sirs");
        $hailo->reply("hello it's fun") for 1 .. 100;
        return join '', uniq(map { $hailo->reply("hello") } 1 .. 100);
    }->(),
    "Hello there good sirs.",
    "Hailo learns / replies",
);

# reply
dies_ok {
    my $hailo = Hailo->new( reply_str => "foo ")->run
} "reply_str with no other options should fail";

# reply with empty brain
{
    my $hailo = Hailo->new;
    my $reply = $hailo->reply("foo");
    is($reply, undef, "If hailo doesn't know anything he should return undef, and not spew warnings");
}

# learn_reply_str
is( sub {
        my $hailo = Hailo->new;
        $hailo->learn_reply("hello there good sirs");
    }->(),
    "Hello there good sirs.",
    "Hailo learns & replies",
);

# order
dies_ok { Hailo->new( order => undef ) } "undef order";
dies_ok { Hailo->new( order => "foo" ) } "Str order";
for (my $i = 1; $i <= 10e10; $i += $i * 2) {
    cmp_ok( Hailo->new( order => $i )->order, '==', $i, "The order is what we put in ($i)" );
}

# new
dies_ok { Hailo->new( qw( a b c d ) ) } "Hailo dies on unknown arguments";
