use 5.010;
use strict;
use warnings;
use Test::More tests => 2;
use Hailo::UI::ReadLine;

my $readline = Hailo::UI::ReadLine->new;
is($ENV{PERL_RL}, 'Perl o=0', "Using Term::ReadLine::Perl");

$ENV{PERL_RL} = 'Mooo';
my $readline2 = Hailo::UI::ReadLine->new;
is($ENV{PERL_RL}, 'Mooo', "... unless the user picks something else");
