use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More tests => 1;
use IO::Handle;
use File::Temp qw< tempdir tempfile >;
use File::Slurp qw< slurp >;
use Pod::Text;

my $module = catfile('lib', 'Hailo.pm');
my $readme = 'README.pod';

my $expected = parsed_pod($module);
my $got = parsed_pod($module);

is($got, $expected, 'README.pod is up to date');

sub parsed_pod {
    my ($file) = @_;
    my $slurp = slurp $file;

    my $dir = tempdir( CLEANUP => 1 );
    my ($out_fh, $filename) = tempfile( DIR => $dir );
    
    my $parser = Pod::Text->new();
    $parser->output_fh( $out_fh );
    $parser->parse_string_document( $slurp );

    $out_fh->sync();
    close $out_fh;

    # Do *not* convert this to something that doesn't use open() for
    # cleverness, that breaks UTF-8 pod files.
    open(my $fh, "<", $filename) or die "Can't open file '$filename'";
    my $content = do { local $/; <$fh> };
    close $fh;

    return $content;
}
