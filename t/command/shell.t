use 5.010;
use strict;
use warnings;
use Test::Script::Run;
use Test::More tests => 50;

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
    like($stdout, qr{--progress\s+Print import progress}, 'Got --progress');
    like($stdout, qr{files are assumed to be UTF-8 encoded}, 'Got UTF-8 note');
    unlike($stdout, qr{examples:}, "no examples on normal output");
}

{
    my ($return, $stdout, $stderr) = run_script( $app, [ '--blah-blah-blah' ]);
    cmp_ok($return, '==', 1, 'Exit status is correct');
    like($stderr, qr/^$/s, 'no stderr');
    like($stdout, qr/Unknown option: blah-blah-blah/, 'Unknown option');
    like($stdout, qr{usage: hailo}, 'Got usage header');
    like($stdout, qr{--progress\s+Print import progress}, 'Got --progress');
    like($stdout, qr{files are assumed to be UTF-8 encoded}, 'Got UTF-8 note');
    unlike($stdout, qr{examples:}, "no examples on error");

my $good_out = <<'END';
        -v --version           Print version and exit
        -u --ui                Use UI CLASS
        -t --train             Learn from all the lines in FILE, use - for STDIN
        -s --stats             Print statistics about the brain
        -r --reply             Reply to STRING
        -p --progress          Print import progress with Term::ProgressBar
        -o --order             Markov order
        -l --learn             Learn from STRING
        -h --help              This help message
        -b --brain             Load/save brain to/from FILE
        -a --autosave          Save the brain on exit (on by default)
        -T --tokenizer         Use tokenizer CLASS
        -S --storage           Use storage CLASS
        -L --learn-reply       Learn from STRING and reply to it
        --ui-args              Arguments for the UI class
        --tokenizer-args       Arguments for the Tokenizer class
        --storage-args         Arguments for the Storage class
        --examples             Print examples along with the help message
END

    my (@opt) = $good_out =~ /(-[A-Za-z]|--\w+)\b/g;

    like($stdout, qr/$_\b/, "stdout contained $_ option") for @opt;
}

