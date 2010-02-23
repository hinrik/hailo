use 5.010;
use strict;
use warnings;
use Hailo;
use File::Temp qw(tempfile);
use Test::More tests => 1;

my ($fh, $brain_file) = tempfile(SUFFIX => '.sqlite', UNLINK => 1);
my $hailo = Hailo->new(
    storage_class  => 'SQLite',
    brain_resource => $brain_file,
);

# we need to learn something first so the DB file will be initialized
$hailo->learn('foo bar baz');

my $orig_size = -s $brain_file;
$hailo->learn('foo bar baz');
my $new_size = -s $brain_file;

is($new_size, $orig_size, 'Hailo keeps the brain in memory');
