use strict;
use warnings;
use Capture::Tiny 'capture';
use File::Spec::Functions 'catfile';
use Test::More tests => 1;

my $module = catfile('lib', 'Hailo.pm');
my $readme = 'README.pod';

# For some very strange reason this approach always results in the second
# invocation of parse_from_file outputing invalid UTF-8. Even if we try
# flipping them, it's always the latter one which fails.
#use Pod::Text;
#my $expected = capture {
#    Pod::Text->new->parse_from_file($module);
#};
#my $got = capture {
#    Pod::Text->new->parse_from_file($readme);
#};

# fall back to using pod2text(1) for now
$ENV{PERL_UNICODE} = 'O';
my $expected = capture {
    system 'pod2text', $module;
};

my $got = capture {
    system 'pod2text', $readme;
};

is($got, $expected, 'README.pod is up to date');
