package Hailo::Command;

use 5.010;
use Any::Moose;
use Any::Moose 'X::Getopt';
use Any::Moose 'X::Types::'.any_moose() => [qw/Int Str Bool HashRef/];
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use namespace::clean -except => 'meta';

extends 'Hailo';

with any_moose('X::Getopt::Dashes');

has help => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'h',
    cmd_flag      => 'help',
    isa           => Bool,
    is            => 'ro',
    default       => 0,
    documentation => 'This help message',
);

has print_version => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'v',
    cmd_flag      => 'version',
    documentation => 'Print version and exit',
    isa           => Bool,
    is            => 'ro',
);

has '+save_on_exit' => (
    cmd_aliases   => 'a',
    cmd_flag      => 'autosave',
);

has print_progress => (
    cmd_aliases   => 'p',
    cmd_flag      => 'progress',
);

has learn_str => (
    cmd_aliases   => "l",
    cmd_flag      => "learn",
    documentation => "Learn from STRING",
    isa           => Str,
    is            => "ro",
);

has learn_reply_str => (
    cmd_aliases   => "L",
    cmd_flag      => "learn-reply",
    documentation => "Learn from STRING and reply to it",
    isa           => Str,
    is            => "ro",
);

has train_file => (
    cmd_aliases   => "t",
    cmd_flag      => "train",
    documentation => "Learn from all the lines in FILE, use - for STDIN",
    isa           => Str,
    is            => "ro",
);

has reply_str => (
    cmd_aliases   => "r",
    cmd_flag      => "reply",
    documentation => "Reply to STRING",
    isa           => Str,
    is            => "ro",
);

has order => (
    cmd_aliases   => "o",
    cmd_flag      => "order",
);

has brain_resource => (
    cmd_aliases   => "b",
    cmd_flag      => "brain",
);

has print_stats => (
    cmd_aliases   => "s",
    cmd_flag      => "stats",
    documentation => "Print statistics about the brain",
    isa           => Bool,
    is            => "ro",
);

# working classes
has '+storage_class' => (
    cmd_aliases   => "S",
    cmd_flag      => "storage",
);

has '+tokenizer_class' => (
    cmd_aliases   => "T",
    cmd_flag      => "tokenizer",
);

has '+ui_class' => (
    cmd_aliases   => "u",
    cmd_flag      => "ui",
);

# Check validity of options
before run => sub {
    my ($self) = @_;

    if (not $self->_storage_obj->ready and
        (defined $self->reply_str or
         defined $self->train_file or
         defined $self->learn_str or
         defined $self->learn_reply_str)) {
        # TODO: Make this spew out the --help reply just like hailo
        # with invalid options does usually, but only if run via
        # ->new_with_options
        die "To reply/train/learn you must specify options to initialize your storage backend";
    }

    return;
};

sub run {
    my ($self) = @_;

    if ($self->print_version) {
        # Munging strictness because we don't have a version from a
        # Git checkout. Dist::Zilla provides it.
        no strict 'vars';
        my $version = $VERSION // 'dev-git';

        say "hailo $version";
        return;
    }

    if ($self->_is_interactive() and
        $self->_storage_obj->ready and
        not defined $self->train_file and
        not defined $self->learn_str and
        not defined $self->learn_reply_str and
        not defined $self->reply_str and
        not defined $self->print_stats) {

        $self->_ui_obj->run($self);
    }

    $self->train($self->train_file) if defined $self->train_file;
    $self->learn($self->learn_str) if defined $self->learn_str;

    if (defined $self->learn_reply_str) {
        my $answer = $self->learn_reply($self->learn_reply_str);
        say $answer // "I don't know enough to answer you yet.";
    }

    if (defined $self->reply_str) {
        my $answer = $self->reply($self->reply_str);
        say $answer // "I don't know enough to answer you yet.";
    }

    if ($self->print_stats) {
        my ($tok, $ex, $prev, $next) = $self->stats();
        my $order = $self->_storage_obj->order;
        say "Tokens: $tok";
        say "Expression length: $order tokens";
        say "Expressions: $ex";
        say "Links to preceding tokens: $prev";
        say "Links to following tokens: $next";
    }

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

        require FindBin;
        require File::Spec;
        no warnings 'once';

        Pod::Usage::pod2usage(
            -input => File::Spec->catfile($FindBin::Bin, $FindBin::Script),
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

    # Don't spew the example output when something's wrong with the
    # options. It won't all fit on small terminals
    say "\n", $synopsis unless $warning;

    exit 1;
}

__PACKAGE__->meta->make_immutable;
