package main;
use open qw< :encoding(utf8) :std >;
use autodie;
use strict;
use warnings;
use Test::More;
use Hailo;
use File::CountLines qw(count_lines);

# TODO: This test fails at UTF8

plan(skip_all => "You need BRAIN=... with a path to a Hailo brain and LOG= with an irc log") unless $ENV{BRAIN} and $ENV{LOG};

my $cmds = <<'END';
  cp /home/failo/failo/failo.sqlite .
  irchailo-seed -f irssi < ~/.irssi/logs/freenode/#avar.log\  | grep failo: > to-failo.log
  BRAIN=$PWD/failo.sqlite LOG=$PWD/to-failo.log perl -Ilib t/hailo/real_workload.t
Benchmark:
  BRAIN=$PWD/failo.sqlite LOG=$PWD/to-failo.log utils/developer/nytprof-file t/hailo/real_workload.t
END

my $hailo = Hailo->new(
    brain => $ENV{BRAIN},
);

my $lns = count_lines($ENV{LOG});
open my $log, '<:encoding(utf8)', $ENV{LOG};
my $every = 100;

plan(tests => int($lns / $every));

my $i = 1; while (<$log>) {
    chomp;
    s/^\w+: //;
    my $reply = $hailo->reply($_);
    pass("$i/$lns: Got reply '$reply' from Hailo given input '$_'") if $i % $every == 0;
} continue { $i++ }
