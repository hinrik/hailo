use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use File::Spec::Functions qw<catfile>;
use File::Temp qw<tempfile>;
use Hailo;

my (undef, $brainfile) = tempfile(SUFFIX => '.sqlite');
my $trainfile = catfile(qw<t lib Hailo Test megahal.trn>);

my $hailo = Hailo->new(
    storage_class  => 'SQLite',
    brain_resource => $brainfile,
    order          => 5,
);
$hailo->train($trainfile);
$hailo = Hailo->new(
    storage_class  => 'SQLite',
    brain_resource => $brainfile,
    order          => 3,
);

lives_ok { $hailo->reply() } 'Order retrieved from database';
