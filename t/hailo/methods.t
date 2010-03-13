use 5.010;
use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Test::More tests => 12;
use Test::Exception;
use Test::Output;
use Hailo;
use Hailo::Command;

$SIG{__WARN__} = sub {
    print STDERR @_ if $_[0] !~ m/(?:^Issuing rollback|for database handle being DESTROY)/
};

# new
SKIP: {
    if (Any::Moose::mouse_is_preferred()) {
        skip "Mouse doesn't have X::StrictConstructor", 1;
    }
    dies_ok { Hailo->new( qw( a b c d ) ) } "Hailo dies on unknown arguments";
}

# Invalid train file
dies_ok { Hailo->new( train_file => "/this-does-not-exist/$$" )->run }  "Calling Hailo with an invalid training file";

# learn/reply
is_deeply( sub {
        my $hailo = Hailo->new;
        $hailo->learn("hello there good sirs");
        [ uniq(map { $hailo->reply("hello") } 1 .. 100) ];
    }->(),
    [ "Hello there good sirs." ],
    "Hailo learns / replies",
);

# reply with empty brain
{
    my $hailo = Hailo->new;
    my $reply = $hailo->reply("foo");
    is($reply, undef, "If hailo doesn't know anything he should return undef, and not spew warnings");
}

# learn_reply
is( sub {
        my $hailo = Hailo->new;
        $hailo->learn_reply("hello there good sirs");
    }->(),
    "Hello there good sirs.",
    "Hailo learns & replies",
);

# Invalid storage/tokenizer/ui
dies_ok { Hailo->new( storage_class => "Blahblahblah" )->learn_reply("foo") } "Hailo dies on unknown storage_class arguments";
dies_ok { Hailo->new( tokenizer_class => "Blahblahblah" )->learn_reply("foo") } "Hailo dies on unknown tokenizer_class arguments";
dies_ok { my $h = Hailo->new( ui_class => "Blahblahblah" ); $h->_ui->run($h) } "Hailo dies on unknown ui_class arguments";

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

lives_ok {
    my $h = Hailo->new;
    $h->train([])
} "train: ARRAY input interactively";
