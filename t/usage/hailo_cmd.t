use 5.010;
use strict;
use warnings;
use Test::Script::Run;
use Test::More tests => 16;

my $app = 'hailo';

run_not_ok( $app, [], 'hailo with no options' );
run_ok( $app, [ '--version' ], 'hailo with --version' );
run_ok( $app, [ '--version' ], 'hailo with --version' );

{
    my ($return, $stdout, $stderr) = run_script( $app, [ '--help' ]);
    cmp_ok($return, '==', 1, 'Exit status is correct');
    like($stderr, qr/^$/s, 'no stderr');
    like($stdout, qr{usage: hailo}, 'Got usage header');
    like($stdout, qr{--progress\s+Print import progress}, 'Got --progress');
    like($stdout, qr{files are assumed to be UTF-8 encoded}, 'Got UTF-8 note');
    like($stdout, qr{examples:}, "examples on normal output");
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
}
