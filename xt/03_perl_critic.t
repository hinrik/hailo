use 5.10.0;
use strict;
use warnings;
use File::Spec::Functions 'catfile';
use Test::More;
use Test::Perl::Critic;

my $rcfile = catfile( 'xt', 'perlcriticrc' );
Test::Perl::Critic->import( -profile => $rcfile );
all_critic_ok();
