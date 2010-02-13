use 5.10.0;
use lib 't/lib';
use utf8;
use strict;
use warnings;
use Test::More tests => 81;
use Hailo;
use Hailo::Test;
use Data::Random qw(:all);
use File::Temp qw(tempfile tempdir);

#binmode $_, ':encoding(utf8)' for (*STDIN, *STDOUT, *STDERR);

# Suppress PostgreSQL notices
$SIG{__WARN__} = sub { print STDERR @_ if $_[0] !~ m/NOTICE:\s*CREATE TABLE/; };

for my $backend (Hailo::Test::all_storages()) {
    # Skip all tests for this backend?
    my $skip_all;

    # Dir to store our brains
    my $dir = tempdir( CLEANUP => 1 );
    ok($dir, "Got temporary dir $dir");

    my ($fh, $filename) = tempfile( DIR => $dir, SUFFIX => '.db' );
    ok($filename, "Got temporary file $filename");

    for my $i (1 .. 5) {
      SKIP: {
        my $tmp_dir = tempdir( DIR => $dir );
        my $test = Hailo::Test->new(
            storage => $backend,
            brain_resource => $filename,
            tempdir => $tmp_dir,
        );
        my $skip_all = ! $test->spawn_storage();
        skip "Didn't create $backend db, can't test it", 2 if $skip_all;

        my ($err, $words) = $test->train_a_few_words();

        skip "Couldn't load backend $backend: $@", 1 if $err;

        # Hailo replies
        cmp_ok(length($test->hailo->reply($words->[5])) * 2, '>', length($words->[5]), "Hailo knows how to babble, try $i");

        $test->unspawn_storage();

        undef $test->{hailo};
      }
    }

    # Don't skip for the next backend
    $skip_all = 0;
}
