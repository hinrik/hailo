use strict;
use warnings;
use Test::More tests => 80;
use Test::Exception;
use File::Spec::Functions qw<catfile>;
use File::Temp qw<tempdir tempfile>;
use File::Slurp qw<slurp>;
use Hailo;

# Dir to store our brains
my $dir = tempdir( "hailo-test-dbd-so-XXXX", CLEANUP => 1, TMPDIR => 1 );

my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite', EXLOCK => 1 );

my $trainfile = catfile(qw<t lib Hailo Test starcraft.trn>);
my @train = split /\n/, slurp($trainfile);
@train = @train[0 .. 5];

for my $iter (1 .. 5) {
{
    my $order = 3;
    my $hailo = Hailo->new(
        storage_class  => 'SQLite',
        brain          => $brain_file,
        order          => $order,
    );
    ok($hailo, "$iter: Constructed a Hailo with order = $order");
    for (@train) {
        $hailo->learn($_);
        pass("$iter: Learned $_ with order $order");
    }
    lives_ok { $hailo->reply() } "$iter: Order retrieved from arguments";
}

{
    my $order = 5;
    my $hailo = Hailo->new(
        storage_class  => 'SQLite',
        brain          => $brain_file,
        order          => $order,
    );
    ok($hailo, "$iter: Constructed a Hailo with order = $order");
    for (@train) {
        $hailo->learn($_);
        pass("$iter: Learned $_ with order $order");
    }
    lives_ok { $hailo->reply() } "$iter: Order retrieved from database";
}
}

