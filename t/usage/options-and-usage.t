use 5.010;
use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Test::More tests => 25;
use Test::Exception;
use Test::Output;
use Hailo;

$SIG{__WARN__} = sub {
    print STDERR @_ if $_[0] !~ m/(?:^Issuing rollback|for database handle being DESTROY)/
};

my $has_test_exit = sub {
    local $@ = undef;
    eval {
        require Test::Exit;
        Test::Exit->import;
    };
    return 1 unless $@;
    return;
}->();

if ($has_test_exit) {
    # --version
    stdout_like(
        sub {
            never_exits_ok( sub { Hailo->new( print_version => 1)->run }, "exiting exits")
        },
        qr/^hailo (?:dev-git|[0-9.]+)$/,
        "Hailo prints its version",
    );
} else {
  SKIP: {
    skip "We don't have Test::Exit, skipping never_exits_ok() test", 2;
  }
}

### Options

# Invalid train file
dies_ok { Hailo->new( train_file => "/this-does-not-exist/$$" )->run }  "Calling Hailo with an invalid training file";

# Valid train file
lives_ok {
    Hailo->new(
        train_file     => __FILE__,
        print_progress => 0,
        brain_resource => ':memory:',
    )->run
}  "Calling Hailo with a valid training file";

# learn_str
lives_ok {
    Hailo->new(
        learn_str      => "foo",
        brain_resource => ':memory:',
    )->run
} "Hailo can learn from a string";

# learn/reply
is( sub {
        my $hailo = Hailo->new;
        $hailo->learn("hello there good sirs");
        #$hailo->reply("hello it's fun") for 1 .. 100;
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
for (my $i = 1; $i <= 10e2; $i += $i * 2) {
    cmp_ok( Hailo->new( order => $i )->order, '==', $i, "The order is what we put in ($i)" );
}

# new
SKIP: {
    if (Any::Moose::mouse_is_preferred()) {
        skip "Mouse doesn't have X::StrictConstructor", 1;
    }
    dies_ok { Hailo->new( qw( a b c d ) ) } "Hailo dies on unknown arguments";
}

# Invalid storage/tokenizer/ui
dies_ok { Hailo->new( storage_class => "Blahblahblah" )->learn_reply("foo") } "Hailo dies on unknown storage_class arguments";
dies_ok { Hailo->new( tokenizer_class => "Blahblahblah" )->learn_reply("foo") } "Hailo dies on unknown tokenizer_class arguments";
dies_ok { my $h = Hailo->new( ui_class => "Blahblahblah" ); $h->_ui_obj->run($h) } "Hailo dies on unknown ui_class arguments";

### Usage

# train
dies_ok {
    my $h = Hailo->new;
    $h->train(undef)
} "train: undef input";

dies_ok {
    my $h = Hailo->new;
    $h->train()
} "train: undef input";

lives_ok {
    my $h = Hailo->new;
    $h->train([])
} "train: ARRAY input";
