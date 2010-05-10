package Hailo::Command;

use 5.010;
use Any::Moose;
use Any::Moose 'X::Getopt';
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use namespace::clean -except => 'meta';

extends 'Hailo';

with any_moose('X::Getopt::Dashes');

## Our internal Getopts method that Hailo.pm doesn't care about.

has help => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => 'h',
    cmd_flag      => 'help',
    isa           => 'Bool',
    is            => 'ro',
    default       => 0,
    documentation => "You're soaking it in",
);

has _go_version => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => 'v',
    cmd_flag      => 'version',
    documentation => 'Print version and exit',
    isa           => 'Bool',
    is            => 'ro',
);

has _go_examples => (
    traits        => [ qw/ Getopt / ],
    cmd_flag      => 'examples',
    documentation => 'Print examples along with the help message',
    isa           => 'Bool',
    is            => 'ro',
);

has _go_progress => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => 'p',
    cmd_flag      => 'progress',
    documentation => 'Display progress during the import',
    isa           => 'Bool',
    is            => 'ro',
    default       => sub {
        my ($self) = @_;
        $self->_is_interactive();
    },
);

has _go_learn => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "l",
    cmd_flag      => "learn",
    documentation => "Learn from STRING",
    isa           => 'Str',
    is            => "ro",
);

has _go_learn_reply => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "L",
    cmd_flag      => "learn-reply",
    documentation => "Learn from STRING and reply to it",
    isa           => 'Str',
    is            => "ro",
);

has _go_train => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "t",
    cmd_flag      => "train",
    documentation => "Learn from all the lines in FILE, use - for STDIN",
    isa           => 'Str',
    is            => "ro",
);

has _go_reply => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "r",
    cmd_flag      => "reply",
    documentation => "Reply to STRING",
    isa           => 'Str',
    is            => "ro",
);

has _go_random_reply => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "R",
    cmd_flag      => "random-reply",
    documentation => "Like --reply but takes no STRING; Babble at random",
    isa           => 'Bool',
    is            => "ro",
);

has _go_stats => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "s",
    cmd_flag      => "stats",
    documentation => "Print statistics about the brain",
    isa           => 'Bool',
    is            => "ro",
);

## Things we have to pass to Hailo.pm via triggers when they're set

has _go_autosave => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => 'a',
    cmd_flag      => 'autosave',
    documentation => 'Save the brain on exit (on by default)',
    isa           => 'Bool',
    is            => 'rw',
    trigger       => sub {
        my ($self, $bool) = @_;
        $self->save_on_exit($bool);
    },
);

has _go_order => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "o",
    cmd_flag      => "order",
    documentation => "Markov order; How deep the rabbit hole goes",
    isa           => 'Int',
    is            => "rw",
    trigger       => sub {
        my ($self, $order) = @_;
        $self->order($order);
    },
);

has _go_brain => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "b",
    cmd_flag      => "brain",
    documentation => "Load/save brain to/from FILE",
    isa           => 'Str',
    is            => "ro",
    trigger       => sub {
        my ($self, $brain) = @_;
        $self->brain($brain);
    },
);

# working classes
has _go_engine_class => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "E",
    cmd_flag      => "engine",
    isa           => 'Str',
    is            => "rw",
    documentation => "Use engine CLASS",
    trigger       => sub {
        my ($self, $class) = @_;
        $self->engine_class($class);
    },
);

has _go_storage_class => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "S",
    cmd_flag      => "storage",
    isa           => 'Str',
    is            => "rw",
    documentation => "Use storage CLASS",
    trigger       => sub {
        my ($self, $class) = @_;
        $self->storage_class($class);
    },
);

has _go_tokenizer_class => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "T",
    cmd_flag      => "tokenizer",
    isa           => 'Str',
    is            => "rw",
    documentation => "Use tokenizer CLASS",
    trigger       => sub {
        my ($self, $class) = @_;
        $self->tokenizer_class($class);
    },
);

has _go_ui_class => (
    traits        => [ qw/ Getopt / ],
    cmd_aliases   => "u",
    cmd_flag      => "ui",
    isa           => 'Str',
    is            => "rw",
    documentation => "Use UI CLASS",
    trigger       => sub {
        my ($self, $class) = @_;
        $self->ui_class($class);
    },
);

# Stop Hailo from polluting our command-line interface
for (qw/ save_on_exit order brain /, map { qq[${_}_class] } qw/ engine storage tokenizer ui /) {
    has "+$_" => (
        traits => [ qw/ NoGetopt / ],
    );
}

# Check validity of options
before run => sub {
    my ($self) = @_;

    if (not $self->_storage->ready and
        (defined $self->_go_reply or
         defined $self->_go_train or
         defined $self->_go_learn or
         defined $self->_go_learn_reply or
         defined $self->_go_random_reply)) {
        # TODO: Make this spew out the --help reply just like hailo
        # with invalid options does usually, but only if run via
        # ->new_with_options
        die "To reply/train/learn you must specify options to initialize your storage backend";
    }

    return;
};

sub run {
    my ($self) = @_;

    if ($self->_go_version) {
        # Munging strictness because we don't have a version from a
        # Git checkout. Dist::Zilla provides it.
        no strict 'vars';
        my $version = $VERSION // 'dev-git';

        say "hailo $version";
        return;
    }

    if ($self->_is_interactive() and
        $self->_storage->ready and
        not defined $self->_go_train and
        not defined $self->_go_learn and
        not defined $self->_go_reply and
        not defined $self->_go_learn_reply and
        not defined $self->_go_stats and
        not defined $self->_go_random_reply) {
        $self->_ui->run($self);
    }

    $self->train($self->_go_train) if defined $self->_go_train;
    $self->learn($self->_go_learn) if defined $self->_go_learn;

    if (defined $self->_go_learn_reply) {
        my $answer = $self->learn_reply($self->_go_learn_reply);
        say $answer // "I don't know enough to answer you yet.";
    }

    if (defined $self->_go_random_reply) {
        my $answer = $self->reply();
        say $answer // "I don't know enough to answer you yet.";
    }
    elsif (defined $self->_go_reply) {
        my $answer = $self->reply($self->_go_reply);
        say $answer // "I don't know enough to answer you yet.";
    }

    if ($self->_go_stats) {
        my ($tok, $ex, $prev, $next) = $self->stats();
        my $order = $self->_storage->order;
        say "Tokens: $tok";
        say "Expression length: $order tokens";
        say "Expressions: $ex";
        say "Links to preceding tokens: $prev";
        say "Links to following tokens: $next";
    }

    return;
}

override _train_fh => sub {
    my ($self, $fh, $filename) = @_;

    if ($self->_is_interactive) {
        $self->train_progress($fh, $filename);
    } else {
        super();
    }
};

before train_progress => sub {
    require Term::Sk;
    require File::CountLines;
    File::CountLines->import('count_lines');
    require Time::HiRes;
    Time::HiRes->import(qw(gettimeofday tv_interval));
    return;
};

sub train_progress {
    my ($self, $fh, $filename) = @_;
    my $lines = count_lines($filename);
    my $progress = Term::Sk->new('%d Elapsed: %8t %21b %4p %2d (%8c of %11m)', {
        # Start at line 1, not 0
        base => 1,
        target => $lines,
        # Every 0.1 seconds for long files
        freq => ($lines < 10_000 ? 10 : 'd'),
    }) or die "Error in Term::Sk->new: (code $Term::Sk::errcode) $Term::Sk::errmsg";

    my $next_update = 0;
    my $start_time = [gettimeofday()];

    my $i = 1; while (my $line = <$fh>) {
        chomp $line;
        $self->_learn_one($line);
        $progress->up;
    } continue { $i++ }

    $progress->close;

    my $elapsed = tv_interval($start_time);
    say sprintf "Trained from %d lines in %.2f seconds; %.2f lines/s", $i, $elapsed, ($i / $elapsed);

    return;
}

# --i--do-not-exist
sub _getopt_spec_exception { goto &_getopt_full_usage }

# --help
sub _getopt_full_usage {
    my ($self, $usage, $plain_str) = @_;

    # If called from _getopt_spec_exception we get "Unknown option: foo"
    my $warning = ref $usage eq 'ARRAY' ? $usage->[0] : undef;

    my ($use, $options) = do {
        # $plain_str under _getopt_spec_exception
        my $out = $plain_str // $usage->text;

        # The default getopt order sucks, use reverse sort order
        chomp(my @out = split /^/, $out);
        my $opt = join "\n", sort { $b cmp $a } @out[1 .. $#out];
        ($out[0], $opt);
    };
    my $synopsis = do {
        require Pod::Usage;
        my $out;
        open my $fh, '>', \$out;

        no warnings 'once';

        my $hailo = File::Spec->catfile($Hailo::Command::HERE_MOMMY, 'hailo');
        # Try not to fail on Win32 or other odd systems which might have hailo.pl not hailo
        $hailo = ((glob("$hailo*"))[0]) unless -f $hailo;
        Pod::Usage::pod2usage(
            -input => $hailo,
            -sections => 'SYNOPSIS',
            -output   => $fh,
            -exitval  => 'noexit',
        );
        close $fh;

        $out =~ s/\n+$//s;
        $out =~ s/^Usage:/examples:/;

        $out;
    };

    # Unknown option provided
    print $warning if $warning;

    print <<"USAGE";
$use
$options
\n\tNote: All input/output and files are assumed to be UTF-8 encoded.
USAGE

    # Hack: We can't get at our object from here so we have to inspect
    # @ARGV directly.
    say "\n", $synopsis if "@ARGV" ~~ /--examples/;

    exit 1;
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

Hailo::Command - Class for the L<hailo> command-line interface to L<Hailo>

=head1 DESCRIPTION

This is an internal class L<hailo> uses for its command-line
interface. See L<Hailo> for the public interface.

=head1 PRIVATE METHODS

=head2 C<run>

Run Hailo in accordance with the the attributes that were passed to
it, this method is called by the L<hailo> command-line utility and the
Hailo test suite, its behavior is subject to change.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
