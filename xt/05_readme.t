use strict;
use warnings;
use Capture::Tiny 'capture';
use File::Spec::Functions 'catfile';
use Pod::Text;
use Test::More tests => 1;

my $expected = capture {
    Pod::Text->new->parse_from_file(catfile(qw(lib Hailo.pm)));
};

open my $readme, '<', 'README';
my $got = do { local $/; <$readme> };

is($got, $expected, 'README file is up to date');
