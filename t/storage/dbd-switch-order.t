use strict;
use warnings;
use Test::More tests => 815;
use Test::Exception;
use File::Temp qw<tempdir tempfile>;
use File::Slurp qw<slurp>;
use Bot::Training;
use Hailo;

# Dir to store our brains
my $dir = tempdir( "hailo-test-dbd-so-XXXX", CLEANUP => 1, TMPDIR => 1 );

my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite', EXLOCK => 0 );

my $trainfile = Bot::Training->new->file("starcraft")->file;
my @train = split /\n/, slurp($trainfile);

my $initial_order = 3;

{
    ok(-f $brain_file, "$brain_file is still -f");
    my $hailo = Hailo->new(
        brain  => $brain_file,
        order  => $initial_order,
    );
    ok($hailo, "Construct a new Hailo with a non-standard order");
    is($hailo->order, $initial_order, "order = $initial_order");
    $hailo->train(\@train);
    my ($tokens) = $hailo->stats;
    is($tokens, 397, "Hailo now knows about 397 tokens");
}

{
    ok(-f $brain_file, "$brain_file is still -f");
    my $hailo = Hailo->new(
        brain  => $brain_file,
    );
    ok($hailo, "Construct a new Hailo from an existing brain");
    is($hailo->order, 2, "Standard order is still 2");
    my $reply = $hailo->reply();
    ok($reply, "Got reply $reply from Hailo");
    is($hailo->order, $initial_order, "Order has been loaded from the database");
    is($hailo->_engine->order, $initial_order, "Order has been propagated from the database -> engine");
    is($hailo->_storage->order, $initial_order, "Order has been propagated from the database -> storage");
    my ($tokens) = $hailo->stats;
    is($tokens, 397, "Hailo still knows about 397 tokens");
}

for my $order (1 .. 200) {
    ok(-f $brain_file, "$brain_file is still -f");
    my $hailo = Hailo->new(
        brain  => $brain_file,
        order  => $order,
    );
    ok($hailo, "Construct a new Hailo from an existing brain with order = $order");
    is($hailo->order, $order, "Custom order is now $order");
    if ($order == $initial_order) {
        my $reply = $hailo->reply();
        ok($reply, "Got reply $reply from Hailo");
        is($hailo->_engine->order, $initial_order, "Order has been propagated from the database -> engine");
        is($hailo->_storage->order, $initial_order, "Order has been propagated from the database -> storage");
        my ($tokens) = $hailo->stats;
        is($tokens, 397, "Hailo still knows about 397 tokens");
    } else {
        local $@;
        eval { $hailo->reply() };
        like($@, qr/manually/, "Tried to reply after setting custom order $order");
    }
}
