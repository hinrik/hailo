use 5.010;
use strict;
use warnings;
use List::MoreUtils qw(uniq);
use Test::Exception;
use Test::Output;
use Hailo::Command;
use Test::More tests => 17;

SKIP: {
    if (Any::Moose::mouse_is_preferred()) {
        skip "Mouse doesn't have X::StrictConstructor", 1;
    }
    dies_ok { Hailo::Command->new( qw( a b c d ) ) } "Hailo dies on unknown arguments";
}

## before run
for (qw/ _go_reply _go_train _go_learn _go_learn_reply /) {
    my $cmd = Hailo::Command->new(
        $_ => "blah",
        _go_storage_class => "PostgreSQL",
    );
    local $@;
    eval { $cmd->run };
    like($@, qr/you must specify options/, "before run -> $_ => with an unininialized backend fails");
}

## run
stdout_like(
    sub {
        Hailo::Command->new( _go_version => 1)->run;
    },
    qr/^hailo (?:dev-git|[0-9.]+)$/,
    "run -> print version",
);

# run -> train()
lives_ok {
    Hailo::Command->new(
        _go_train     => __FILE__,
        _go_progress  => 0,
        _go_brain     => ':memory:',
    )->run
} "run -> train()";

lives_ok {
    Hailo::Command->new(
        _go_train     => __FILE__,
        _go_progress  => 0,
        _go_brain     => ':memory:',
    )->run
}  "run -> learn()";

for (qw/ _go_reply _go_learn_reply /) {
    stdout_unlike(
        sub {
            Hailo::Command->new(
                _go_train     => __FILE__,
                _go_progress  => 0,
                $_            => "run",
                _go_brain     => ':memory:',
            )->run;
        },
        qr/^$/,
        "run -> train() & $_() with a trained brain"
    );
}

for (qw/ _go_reply _go_learn_reply /) {
    stdout_like(
        sub {
            Hailo::Command->new(
                _go_progress  => 0,
                $_            => "run",
                _go_brain     => ':memory:',
            )->run;
        },
        qr/I don't know enough to answer you yet/,
        "run -> train() & $_() with an untrained brain"
    );
}


for (qr/Tokens/, qr/Expression/, qr/Expressions/, qr/Links to preceding/, qr/Links to following/) {
    stdout_like(
        sub {
            Hailo::Command->new(
                _go_train     => __FILE__,
                _go_progress  => 0,
                _go_stats     => 1,
                _go_brain     => ':memory:',
            )->run;
        },
        $_,
        "run -> train() & stats() matches $_",
    );
}
