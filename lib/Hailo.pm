package Hailo;

use 5.010;
use autodie qw(open close);
use Class::MOP;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw/Int Str Bool HashRef/;
use MooseX::Getopt;
use Module::Pluggable (
    search_path => [ map { "Hailo::$_" } qw(Storage Tokenizer UI) ],
    except      => [
        # If an old version of Hailo is already istalled these modules
        # may be lying around. Ignore them manually; and make sure to
        # update this list if we move things around again.
        map( { qq[Hailo::Storage::$_] } qw(SQL SQLite Pg mysql)),
    ],
);
use List::Util qw(first);
use namespace::clean -except => [ qw(meta plugins) ];

our $VERSION = '0.16';

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

has save_on_exit => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'a',
    cmd_flag      => 'autosave',
    documentation => 'Save the brain on exit (on by default)',
    isa           => Bool,
    is            => 'ro',
    default       => 1,
);

has print_progress => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'p',
    cmd_flag      => 'progress',
    documentation => 'Print import progress with Term::ProgressBar',
    isa           => Bool,
    is            => 'ro',
    default       => sub { _is_interactive() }
);

has learn_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "l",
    cmd_flag      => "learn",
    documentation => "Learn from STRING",
    isa           => Str,
    is            => "ro",
);

has learn_reply_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "L",
    cmd_flag      => "learn-reply",
    documentation => "Learn from STRING and reply to it",
    isa           => Str,
    is            => "ro",
);

has train_file => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "t",
    cmd_flag      => "train",
    documentation => "Learn from all the lines in FILE",
    isa           => Str,
    is            => "ro",
);

has reply_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "r",
    cmd_flag      => "reply",
    documentation => "Reply to STRING",
    isa           => Str,
    is            => "ro",
);

has order => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "o",
    cmd_flag      => "order",
    documentation => "Markov order",
    isa           => Int,
    is            => "ro",
    default       => 2,
);

has brain_resource => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "b",
    cmd_flag      => "brain",
    documentation => "Load/save brain to/from FILE",
    isa           => Str,
    is            => "ro",
);

has print_stats => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "s",
    cmd_flag      => "stats",
    documentation => "Print statistics about the brain",
    isa           => Bool,
    is            => "ro",
);

# working classes
has storage_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "S",
    cmd_flag      => "storage",
    documentation => "Use storage CLASS",
    isa           => Str,
    is            => "ro",
    default       => "SQLite",
);

has tokenizer_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "T",
    cmd_flag      => "tokenizer",
    documentation => "Use tokenizer CLASS",
    isa           => Str,
    is            => "ro",
    default       => "Words",
);

has ui_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "u",
    cmd_flag      => "ui",
    documentation => "Use UI CLASS",
    isa           => Str,
    is            => "ro",
    default       => "ReadLine",
);

# Object arguments
has storage_args => (
    traits        => [qw(Getopt)],
    documentation => "Arguments for the Storage class",
    isa           => HashRef,
    coerce        => 1,
    is            => "ro",
    default       => sub { +{} },
);

has tokenizer_args => (
    traits        => [qw(Getopt)],
    documentation => "Arguments for the Tokenizer class",
    isa           => HashRef,
    is            => "ro",
    default       => sub { +{} },
);

has ui_args => (
    traits        => [qw(Getopt)],
    documentation => "Arguments for the UI class",
    isa           => HashRef,
    is            => "ro",
    default       => sub { +{} },
);

# Working objects
has _storage_obj => (
    traits      => [qw(NoGetopt)],
    does        => 'Hailo::Role::Storage',
    lazy_build  => 1,
    is          => 'ro',
    init_arg    => undef,
);

has _tokenizer_obj => (
    traits      => [qw(NoGetopt)],
    does        => 'Hailo::Role::Tokenizer',
    lazy_build  => 1,
    is          => 'ro',
    init_arg    => undef,
);

has _ui_obj => (
    traits      => [qw(NoGetopt)],
    does        => 'Hailo::Role::UI',
    lazy_build  => 1,
    is          => 'ro',
    init_arg    => undef,
);

with qw(MooseX::Getopt::Dashes);


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



sub _build__storage_obj {
    my ($self) = @_;
    my $obj = $self->_new_class(
        "Storage",
        $self->storage_class,
        {
            (defined $self->brain_resource
             ? (brain => $self->brain_resource)
             : ()),
            order           => $self->order,
            arguments       => $self->storage_args,
        }
    );
    
    return $obj;
}

sub _build__tokenizer_obj {
    my ($self) = @_;
    my $obj = $self->_new_class(
        "Tokenizer",
        $self->tokenizer_class,
        {
            arguments => $self->tokenizer_args,
        },
    );

    return $obj;
}

sub _build__ui_obj {
    my ($self) = @_;
    my $obj = $self->_new_class(
        "UI",
        $self->ui_class,
        {
            arguments => $self->ui_args,
        },
    );

    return $obj;
}

sub _new_class {
    my ($self, $type, $class, $args) = @_;

    # Be fuzzy about includes, e.g. DBD::SQLite or SQLite or sqlite will go
    my $pkg = first { / $type : .* : $class /ix }
              sort { length $a <=> length $b } $self->plugins;

    unless ($pkg) {
        local $" = ', ';
        my @plugins = grep { /$type/ } $self->plugins;
        die "Couldn't find a class name matching '$class' in plugins '@plugins'";
    }

    eval { Class::MOP::load_class($pkg) };
    die $@ if $@;

    return $pkg->new(%$args);
}

# Check validity of options
before run => sub {
    my ($self) = @_;

    if (not defined $self->brain_resource and
        (defined $self->reply_str or
        defined $self->train_file or
        defined $self->learn_str or
        defined $self->learn_reply_str)) {
        # TODO: Make this spew out the --help reply just like hailo
        # with invalid options does usually, but only if run via
        # ->new_with_options
        die "You must specify a --brain";
    }

    return;
};

sub run {
    my ($self) = @_;

    if ($self->print_version) {
        say "hailo $VERSION";
        return;
    }

    if (_is_interactive() and
        defined $self->brain_resource and
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

sub save {
    my $self = shift;
    $self->_storage_obj->save(@_);
    return;
}

sub train {
    my ($self, $input) = @_;
    my $storage = $self->_storage_obj;
    $storage->start_training();

    my $got_filename = ref $input eq '';

    my $fh;
    if (ref $input eq 'GLOB') {
        $fh = $input;
    }
    elsif ($got_filename) {
        open $fh, '<:encoding(utf8)', $input;
    }

    if ($self->print_progress) {
        $self->_train_progress($fh, $input);
    }
    elsif (ref $input eq 'ARRAY') {
        for my $line (@$input) {
            $self->_learn_one($line);
        }
    }
    else {
        while (my $line = <$fh>) {
            chomp $line;
            $self->_learn_one($line);
        }
    }

    close $fh if $got_filename;
    $storage->stop_training();
    return;
}

before _train_progress => sub {
    require Term::ProgressBar;
    Term::ProgressBar->import(2.00);
    require File::CountLines;
    File::CountLines->import('count_lines');
    require Time::HiRes;
    Time::HiRes->import(qw(gettimeofday tv_interval));
    return;
};

sub _train_progress {
    my ($self, $fh, $filename) = @_;
    my $lines = count_lines($filename);
    my $progress = Term::ProgressBar->new({
        name => "training from $filename",
        count => $lines,
        remove => 1,
        ETA => 'linear',
    });
    $progress->minor(0);
    my $next_update = 0;
    my $start_time = [gettimeofday()];

    my $i = 1; while (my $line = <$fh>) {
        chomp $line;
        $self->_learn_one($line);
        if ($i >= $next_update) {
            $next_update = $progress->update($.);

            # The default Term::ProgressBar estimate for next updates
            # is way too concervative. With a ~200k line file we only
            # update every ~2k lines which is 10 seconds or so.
            $next_update = (($next_update-$i) / 10) + $i;
        }
    } continue { $i++ }

    $progress->update($lines) if $lines >= $next_update;
    my $elapsed = tv_interval($start_time);
    say "Imported in $elapsed seconds";

    return;
}

sub learn {
    my ($self, $input) = @_;
    my $inputs = ref $input eq 'ARRAY' ? $input : [$input];
    my $storage = $self->_storage_obj;

    $storage->start_learning();
    $self->_learn_one($_) for @$inputs;
    $storage->stop_learning();
    return;
}

sub _learn_one {
    my ($self, $input) = @_;
    my $storage = $self->_storage_obj;
    my $order   = $storage->order;

    my $tokens = $self->_tokenizer_obj->make_tokens($input);

    # only learn from inputs which are long enough
    return if @$tokens < $order;

    $storage->learn_tokens($tokens);
    return;
}

sub learn_reply {
    my ($self, $input) = @_;
    $self->learn($input);
    return $self->reply($input);
}

sub reply {
    my ($self, $input) = @_;
    my $storage = $self->_storage_obj;
    my $toke    = $self->_tokenizer_obj;

    my $reply;
    if (defined $input) {
        my $tokens = $toke->make_tokens($input);
        $reply = $storage->make_reply($tokens);
    }
    else {
        $reply = $storage->make_reply();
    }

    return if !defined $reply;
    return $toke->make_output($reply);
}

sub stats {
    my ($self) = @_;
    my $storage = $self->_storage_obj;
    return $storage->totals();
}

sub DEMOLISH {
    my ($self) = @_;
    $self->save if $self->save_on_exit;
    return;
}

sub _is_interactive {
    require IO::Interactive;
    return IO::Interactive::is_interactive();
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo - A pluggable Markov engine analogous to MegaHAL

=head1 SYNOPSIS

This is the synopsis for using Hailo as a module. See L<hailo> for
command-line invocation.

    # Hailo requires Perl 5.10
    use 5.010;
    use Hailo;

    # Construct a new in-memory Hailo using the SQLite backend. See
    # backend documentation for other options.
    my $hailo = Hailo->new;

    # Various ways to learn
    my @train_this = qw< I like big butts and I can not lie >;
    $hailo->learn(\@train_this);
    $hailo->learn($_) for @train_this;

    # Heavy-duty training interface. Backends may drop some safety
    # features like journals or synchronous IO to train faster using
    # this mode.
    $hailo->learn("megahal.trn");
    $hailo->learn($filehandle);

    # Make the brain babble
    say $hailo->reply("hello good sir.");

=head1 DESCRIPTION

Hailo is a fast and lightweight markov engine intended to replace
L<AI::MegaHAL|AI::MegaHAL>. It has a lightweight L<Moose|Moose>-based core
with pluggable L<storage|Hailo::Role::Storage> and
L<tokenizer|Hailo::Role::Tokenizer> backends.

It is similar to MegaHAL in functionality, the main differences (with the
default backends) being better scalability, drastically less memory usage,
an improved tokenizer, and tidier output.

With this distribution, you can create, modify, and query Hailo brains. To
use Hailo in event-driven POE applications, you can use the
L<POE::Component::Hailo|POE::Component::Hailo> wrapper. One example is
L<POE::Component::IRC::Plugin::Hailo|POE::Component::IRC::Plugin::Hailo>,
which implements an IRC chat bot.

=head2 Etymology

I<Hailo> is a portmanteau of I<HAL> (as in MegaHAL) and
L<failo|http://identi.ca/failo>.

=head1 ATTRIBUTES

=head2 C<brain_resource>

The name of the resource (file name, database name) to use as storage.
There is no default.

=head2 C<save_on_exit>

A boolean value indicating whether Hailo should save its state before its
object gets destroyed. Defaults to true.

=head2 C<order>

The Markov order (chain length) you want to use for an empty brain.
The default is 5.

=head2 C<storage_class>

The storage backend to use. Default: 'SQLite'.

This gives you an idea of approximately how the backends compare in
speed:
                      Rate DBD::Pg DBD::mysql DBD::SQLite/file DBD::SQLite/memory
 DBD::Pg            1.96/s      --       -20%             -40%               -56%
 DBD::mysql         2.46/s     25%         --             -25%               -45%
 DBD::SQLite/file   3.29/s     67%        34%               --               -27%
 DBD::SQLite/memory 4.50/s    129%        83%              37%                 --

To run your own test try running F<utils/hailo-benchmark> in the Hailo
distribution.

=head2 C<tokenizer_class>

The tokenizer to use. Default: 'Words';

=head2 C<ui_class>

The UI to use. Default: 'ReadLine';

=head2 C<storage_args>

=head2 C<tokenizer_args>

=head2 C<ui_args>

A C<HashRef> of arguments for storage/tokenizer/ui backends. See the
documentation for the backends for what sort of arguments they accept.

=head1 METHODS

=head2 C<new>

This is the constructor. It accepts the attributes specified in
L</ATTRIBUTES>.

=head2 C<run>

Run the application according to the command line arguments.

=head2 C<learn>

Takes a string or an array reference of strings, and learns from them.

=head2 C<train>

Takes a filename, filehandle or array reference and learns from all its
lines. If a filename is passed, the file is assumed to be UTF-8 encoded.
Unlike L<C<learn>|/learn>, this method sacrifices some safety (disables
the database journal, fsyncs, etc) for speed while learning.

=head2 C<reply>

Takes an optional line of text and generates a reply that might be relevant.

=head2 C<learn_reply>

Takes a string argument, learns from it, and generates a reply that might
be relevant.

=head2 C<save>

Tells the underlying storage backend to save its state. To override the
filename you can provide one as an argument.

=head2 C<stats>

Takes no arguments. Returns the number of tokens, expressions, previous
token links and next token links.

=head1 SUPPORT

You can join the IRC channel I<#hailo> on FreeNode if you have questions.

=head1 SEE ALSO

L<Hailo: A Perl rewrite of MegaHAL|
http://blogs.perl.org/users/aevar_arnfjor_bjarmason/2010/01/hailo-a-perl-rewrite-of-megahal.html>
- A blog posting about the motivation behind Hailo

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
