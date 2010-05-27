use 5.010;
use strict;
use warnings;
use Test::Script::Run;
use Test::More tests => 58;

my $app = 'hailo';

## --examples
{
    my ($return, $stdout, $stderr) = run_script( $app, [ '--help', '--examples']);
    like($stdout, qr{examples:}, "no examples on normal output");
}

## Basic usage
run_not_ok( $app, [], 'hailo with no options' );

## --version
run_ok( $app, [ '--version' ], 'hailo with --version' );
run_ok( $app, [ '--version' ], 'hailo with --version' );

## --no-help
run_ok( $app, [ '--no-help' ], "Don't help me" );

## --help
{
    my ($return, $stdout, $stderr) = run_script( $app, [ '--help' ]);
    cmp_ok($return, '==', 1, 'Exit status is correct');
    like($stderr, qr/^$/s, 'no stderr');
    like($stdout, qr{usage: hailo}, 'Got usage header');
    like($stdout, qr{--progress\s+Display progress}, 'Got --progress');
    like($stdout, qr{files are assumed to be UTF-8 encoded}, 'Got UTF-8 note');
    unlike($stdout, qr{examples:}, "no examples on normal output");
}

# --help matches POD in bin/hailo
{
  SKIP: {
    my ($return, $stdout, $stderr) = run_script( $app, [ '--help' ]);

    my $hailo = 'bin/hailo';

    skip "There's no bin/hailo", 1 unless -r $hailo;

    my $content = do {
        local $/;
        open my $fh, "<", $hailo or skip "Couldn't open $hailo: $!", 1;
        <$fh>;
    };

    my $usage = ($content =~ m/^=head1\s+USAGE(.+?)\n^=head1/ms)[0];
    $usage =~ s/^\s*//s;

    my @usage  = split /\n/, $usage;
    my @stdout = split /\n/, $stdout;

    subtest "bin/hailo POD matches --help" => sub {
        for (my $i = 0; $i < @stdout; $i++) {
            is($usage[$i], $stdout[$i], "Line #$i of POD usage matched --help");
        }
        done_testing();
    }
  }
}

{
    my ($return, $stdout, $stderr) = run_script( $app, [ '--blah-blah-blah' ]);
    cmp_ok($return, '==', 1, 'Exit status is correct');
    like($stderr, qr/^$/s, 'no stderr');
    like($stdout, qr/Unknown option: blah-blah-blah/, 'Unknown option');
    like($stdout, qr{usage: hailo}, 'Got usage header');
    like($stdout, qr{--progress\s+Display progress}, 'Got --progress');
    like($stdout, qr{files are assumed to be UTF-8 encoded}, 'Got UTF-8 note');
    unlike($stdout, qr{examples:}, "no examples on error");

    my (@opt) = $stdout =~ /(-[A-Za-z]|--\w+)\b/g;

    like($stdout, qr/$_\b/, "stdout contained $_ option") for @opt;
}

## XXX: Doesn't work!
# ## --reply
# {
#     $DB::single = 1;
#     my ($return, $stdout, $stderr) = run_script( $app, [ '--brain', ':memory:', '--train', '/home/avar/g/hailo/t/command/shell.t', 'my' ]);
#     cmp_ok($return, '==', 0, 'Exit status is correct');
#     like($stderr, qr/^$/s, 'no stderr');
#     ok($stdout, "stdout: $stdout");
# }

# ## --random-reply
# {
#     my ($return, $stdout, $stderr) = run_script( $app, [ '--brain', ':memory:', '--train', abs_path(__FILE__), '--random-reply' ]);
#     cmp_ok($return, '==', 0, 'Exit status is correct');
#     like($stderr, qr/^$/s, 'no stderr');
#     ok($stdout, "stdout: $stdout");
# }
