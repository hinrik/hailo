use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use File::Spec::Functions qw<catfile>;
use File::Temp qw<tempdir tempfile>;
use Hailo;

# Dir to store our brains
my $dir = tempdir( "hailo-test-dbd-so-XXXX", CLEANUP => 1, TMPDIR => 1 );

my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite' );

my $trainfile = catfile(qw<t lib Hailo Test megahal.trn>);

my $hailo = Hailo->new(
    storage_class  => 'SQLite',
    brain_resource => $brain_file,
    order          => 5,
);
$hailo->train($trainfile);
$hailo = Hailo->new(
    storage_class  => 'SQLite',
    brain_resource => $brain_file,
    order          => 3,
);

lives_ok { $hailo->reply() } 'Order retrieved from database';
