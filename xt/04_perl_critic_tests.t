use 5.010;
use strict;
use warnings;
use File::Spec;
use Test::More;
use Perl::Critic::Utils qw(all_perl_files);
use English qw(-no_match_vars);

my $rcfile = File::Spec->catfile( 'xt', 'perlcriticrc_tests' );
require Test::Perl::Critic;
Test::Perl::Critic->import(-profile => $rcfile);
all_critic_ok(all_perl_files('t'));
