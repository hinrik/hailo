package Hailo;

use Moose;
use MooseX::Types::Moose qw/Int Str Bool/;
use MooseX::Types::Path::Class qw(File);
use Time::HiRes qw(gettimeofday tv_interval);
use IO::Interactive qw(is_interactive);
use namespace::clean -except => [ qw(meta
                                     count_lines
                                     gettimeofday
                                     tv_interval) ];

our $VERSION = '0.01';

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

has print_progress => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'p',
    cmd_flag      => 'progress',
    documentation => 'Print import progress with Term::ProgressBar',
    isa           => Bool,
    is            => 'ro',
    default       => sub { is_interactive() },
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
    cmd_flag      => "learn_reply",
    documentation => "Learn from STRING and reply to it",
    isa           => Str,
    is            => "ro",
);

has train_file => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "t",
    cmd_flag      => "train",
    documentation => "Learn from all the lines in FILE",
    isa           => File,
    coerce        => 1,
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
    default       => 5,
);

has brain_resource => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "b",
    cmd_flag      => "brain",
    documentation => "Load/save brain to/from FILE",
    isa           => Str,
    is            => "ro",
);

has token_separator => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'P',
    cmd_flag      => 'separator',
    documentation => "String used when joining an expression into a string",
    isa           => Str,
    is            => 'rw',
    default       => "\t",
);

# Working classes
has engine_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "E",
    cmd_flag      => "engine",
    documentation => "Use engine CLASS",
    isa           => Str,
    is            => "ro",
    default       => "Default",
);

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

# Working objects
has _engine_obj => (
    traits      => [qw(NoGetopt)],
    does        => 'Hailo::Role::Engine',
    lazy_build  => 1,
    is          => 'ro',
    init_arg    => undef,
);

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

with qw(MooseX::Getopt);

sub _getopt_full_usage {
    my ($self, $usage) = @_;
    my $options = do {
        my $out = $usage->text;
        $out  =~ s/\n+$//s;
        $out;
    };
    my $synopsis = do {
        require Pod::Usage;
        my $out;
        open my $fh, '>', \$out or die "Can't open in-memory filehandle";
        Pod::Usage::pod2usage(
            -sections => 'SYNOPSIS',
            -output   => $fh,
            -exitval  => 'noexit',
        );
        close $fh;

        $out =~ s/\n+$//s;
        $out =~ s/^Usage:/examples:/;

        $out;
    };

    print <<"USAGE";
$options
\tNote: All input/output and files are assumed to be UTF-8 encoded.
$synopsis
USAGE

    exit 1;
}

sub _build__engine_obj {
    my ($self) = @_;

    my $engine_class = $self->engine_class;

    my $engine = "Hailo::Engine::$engine_class";
    eval "require $engine";
    die $@ if $@;

    return $engine->new(
        storage   => $self->_storage_obj,
        tokenizer => $self->_tokenizer_obj,
    );
}

sub _build__storage_obj {
    my ($self) = @_;

    my $storage_class = $self->storage_class;
    my $storage = "Hailo::Storage::$storage_class";
    eval "require $storage";
    die $@ if $@;

    my $obj = $storage->new(
        (defined $self->brain_resource
            ? (brain => $self->brain_resource)
            : ()
        ),
        token_separator => $self->token_separator,
        order => $self->order,
    );

    return $obj;
}

sub _build__tokenizer_obj {
    my ($self) = @_;

    my $tokenizer_class = $self->tokenizer_class;

    my $tokenizer = "Hailo::Tokenizer::$tokenizer_class";
    eval "require $tokenizer";
    die $@ if $@;

    return $tokenizer->new();
}

sub run {
    my ($self) = @_;

    if ($self->print_version) {
        print "hailo $VERSION\n";
        exit;
    }

    $self->train($self->train_file) if defined $self->train_file;
    $self->learn($self->learn_str) if defined $self->learn_str;

    if (defined $self->learn_reply_str) {
        my $answer = $self->learn_reply($self->learn_reply_str);
        print "$answer\n";
    }

    if (defined $self->reply_str) {
        my $answer = $self->engine->reply($self->reply_str);
        die "I don't know enough to answer you yet.\n" if !defined $answer;
        print "$answer\n";
    }

    $self->save() if defined $self->brain_resource;
    return;
}

sub save {
    my ($self) = @_;
    $self->_storage_obj->save();
    return;
}

sub train {
    my ($self, $filename) = @_;
    my $storage = $self->_storage_obj;
    $storage->start_training();

    open my $fh, '<:encoding(utf8)', $filename or die "Can't open file '$filename': $!\n";
    if ($self->print_progress) {
        $self->_train_progress($fh, $filename);
    } else {
        while (my $line = <$fh>) {
            chomp $line;
            $self->_do_learn($line);
        }
    }
    close $fh;
    $storage->stop_training();
    return;
}

before _train_progress => sub {
    require Term::ProgressBar;
    Term::ProgressBar->import(2.00);
    require File::CountLines;
    File::CountLines->import('count_lines');
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

    while (my $line = <$fh>) {
        chomp $line;
        $self->_do_learn($line);
        if ($. >= $next_update) {
            $next_update = $progress->update($.);

            # The default Term::ProgressBar estimate for next updates
            # is way too concervative. With a ~200k line file we only
            # update every ~2k lines which is 10 seconds or so.
            $next_update = (($next_update-$.) / 10) + $.;
        }
    }

    $progress->update($lines) if $lines >= $next_update;
    my $elapsed = tv_interval($start_time);
    print "Imported in $elapsed seconds\n";

    return;
}

sub learn {
    my ($self, $input) = @_;
    my $storage = $self->_storage_obj;

    $storage->start_learning();
    $self->_engine_obj->learn($input);
    $storage->stop_learning();
    return;
}

sub reply {
    my ($self, $input) = @_;
    return $self->_engine_obj->reply($input);
}

sub learn_reply {
    my ($self, $input) = @_;
    $self->learn($input);
    return $self->_engine_obj->reply($input);
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo - A pluggable Markov engine analogous to MegaHAL

=head1 SYNOPSIS

    use Hailo;

    my $hailo = Hailo->new(
        # Or Pg, or Perl ...
        storage_class  => 'SQLite',
        brain_resource => 'brain.db'
    );

    while (<>) {
        $hailo->learn($_);
        print $hailo->reply($_), "\n";
    }

=head1 DESCRIPTION

Hailo is a fast and pluggable markov engine intended to replace
L<AI::MegaHAL>. It has a lightweight L<Moose>-based core with
pluggable L<storage backends|Hailo::Role::Storage> and
L<tokenizers|Hailo::Role::Tokenizer>. It's faster than MegaHAL and can
handle huge brains easily with the recommended L<SQLite
backend|Hailo::Storage::SQLite>.

It can be used, amongst other things, to implement IRC chat bots with
L<POE::Component::IRC>.

=head2 Etymology

I<Hailo> is a portmanteau of I<HAL> (as in MegaHAL) and
L<I<failo>|http://identi.ca/failo>

=head1 ATTRIBUTES

=head2 C<brain_resource>

The name of the resource (file name, database name) to use as storage.
There is no default.

=head2 C<order>

The Markov order (chain length) you want to use for an empty brain.
The default is 5.

=head2 C<storage_class>

The storage backend to use. Default: 'SQLite'.

=head2 C<tokenizer_class>

The tokenizer to use. Default: 'Words';

=head2 C<token_separator>

Storage backends may choose to store the tokens of an expression as a single
string. If so, they will be joined them together with a separator. By default,
this is C<"\t">.

=head1 METHODS

=head2 C<new>

This is the constructor. It accept the attributes specified in
L</ATTRIBUTES>.

=head2 C<run>

Run the application according to the command line arguments.

=head2 C<learn>

Takes a line of UTF-8 encoded text as input and learns from it.

=head2 C<train>

Takes a filename and calls L<C<learn>|/learn> on all its lines. Lines are
expected to be UTF-8 encoded.

=head2 C<reply>

Takes a line of text and generates a reply (UTF-8 encoded) that might be
relevant.

=head2 C<learn_reply>

Takes a line of text, learns from it, and generates a reply (UTF-8 encoded)
that might be relevant.

=head2 C<save>

Tells the underlying storage backend to save its state.

=head1 CAVEATS

All occurences of L<C<token_separator>|/token_separator> will be stripped
from your input before it is processed, so make sure it's set to something
that is unlikely to appear in it.

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
