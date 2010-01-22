use strict;
use warnings;
use File::Spec;
use Test::More;
use English qw(-no_match_vars);

eval { require Test::Perl::Critic; };

if ( $EVAL_ERROR ) {
    my $msg = 'Test::Perl::Critic required to criticise code';
    plan( skip_all => $msg );
}
elsif ($Perl::Critic::VERSION lt 1.098) {
    my $msg = 'Perl::Critic >= 1.098 required to criticise code';
    plan( skip_all => $msg );
}

my $rcfile = File::Spec->catfile( 'xt', 'perlcriticrc_tests' );
Test::Perl::Critic->import( -profile => $rcfile );
all_critic_ok(glob 't/0*');
