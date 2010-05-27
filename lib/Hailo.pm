package Hailo;

use 5.010;
use autodie qw(open close);
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use List::Util qw(first);
use namespace::clean -except => 'meta';

has brain => (
    isa => 'Str',
    is  => 'rw',
);

has order => (
    isa     => 'Int',
    is      => 'rw',
    default => 2,
    trigger => sub {
        my ($self, $order) = @_;
        $self->_custom_order(1);
    },
);

has _custom_order => (
    isa           => 'Bool',
    is            => 'rw',
    default       => 0,
    init_arg      => undef,
    documentation => "Here so we can differentiate between the default value of order being explictly set and being set by default",
);

has save_on_exit => (
    isa     => 'Bool',
    is      => 'rw',
    default => 1,
);

has brain_resource => (
    documentation => "Alias for `brain' for backwards compatibility",
    isa           => 'Str',
    is            => 'rw',
    trigger       => sub {
        my ($self, $brain) = @_;
        $self->brain($brain);
    },
);

my %has = (
    engine => {
        name => 'Engine',
        default => 'Default',
    },
    storage => {
        name => 'Storage',
        default => 'SQLite',
    },
    tokenizer => {
        name => 'Tokenizer',
        default => 'Words',
    },
    ui => {
        name => 'UI',
        default => 'ReadLine',
    },
);

for my $k (keys %has) {
    my $name          = $has{$k}->{name};
    my $default       = $has{$k}->{default};
    my $method_class  = "${k}_class";
    my $method_args   = "${k}_args";

    # working classes
    has "${k}_class" => (
        isa           => 'Str',
        is            => "rw",
        default       => $default,
    );

    # Object arguments
    has "${k}_args" => (
        documentation => "Arguments for the $name class",
        isa           => 'HashRef',
        coerce        => 1,
        is            => "ro",
        default       => sub { +{} },
    );

    # Working objects
    has "_${k}" => (
        does        => "Hailo::Role::$name",
        lazy_build  => 1,
        is          => 'ro',
        init_arg    => undef,
    );

    # Generate the object itself
    no strict 'refs';
    *{"_build__${k}"} = sub {
        my ($self) = @_;
        my $obj = $self->_new_class(
            $name,
            $self->$method_class,
            {
                arguments => $self->$method_args,
                ($k ~~ [ qw< engine storage > ]
                 ? (order     => $self->order)
                 : ()),
                ($k ~~ [ qw< engine > ]
                 ? (storage   => $self->_storage)
                 : ()),
                (($k ~~ [ qw< storage > ] and defined $self->brain)
                 ? (
                     hailo => $self,
                     brain => $self->brain
                 )
                 : ()),
            },
        );

        return $obj;
    };
}

sub _plugins { qw[
    Hailo::Engine::Default
    Hailo::Storage::MySQL
    Hailo::Storage::PostgreSQL
    Hailo::Storage::SQLite
    Hailo::Tokenizer::Chars
    Hailo::Tokenizer::Words
    Hailo::UI::ReadLine
] }

sub _new_class {
    my ($self, $type, $class, $args) = @_;

    my $pkg;
    if ($class =~ m[^\+(?<custom_plugin>.+)$]) {
        $pkg = $+{custom_plugin};
    } else {
        # Be fuzzy about includes, e.g. DBD::SQLite or SQLite or sqlite will go
        $pkg = first { / $type : .* : $class /ix }
               sort { length $a <=> length $b }
               $self->_plugins;

        unless ($pkg) {
            local $" = ', ';
            my @plugins = grep { /$type/ } $self->_plugins;
            die "Couldn't find a class name matching '$class' in plugins '@plugins'";
        }
    }

    if (Any::Moose::moose_is_preferred()) {
        require Class::MOP;
        eval { Class::MOP::load_class($pkg) };
    } else {
        eval qq[require $pkg];
    }
    die $@ if $@;

    return $pkg->new(%$args);
}

sub save {
    my ($self) = @_;
    $self->_storage->save(@_);
    return;
}

sub train {
    my ($self, $input) = @_;

    $self->_storage->start_training();

    given ($input) {
        # With STDIN
        when (not ref and defined and $_ eq '-') {
            die "You must provide STDIN when training from '-'" if $self->_is_interactive(*STDIN);
            $self->_train_fh(*STDIN);
        }
        # With a filehandle
        when (ref eq 'GLOB') {
            $self->_train_fh($input);
        }
        # With a file
        when (not ref) {
            open my $fh, '<:encoding(utf8)', $input;
            $self->_train_fh($fh, $input);
        }
        # With an Array
        when (ref eq 'ARRAY') {
            $self->_learn_one($_) for @$input;
        }
        # With something naughty
        default {
            die "Unknown input: $input";
        }
    }

    $self->_storage->stop_training();

    return;
}

sub _train_fh {
    my ($self, $fh, $filename) = @_;

    while (my $line = <$fh>) {
        chomp $line;
        $self->_learn_one($line);
    }

    return;
}

sub learn {
    my ($self, $input) = @_;
    my $inputs;

    given ($input) {
        when (not defined) {
            die "Cannot learn from undef input";
        }
        when (not ref) {
            $inputs = [$input];            
        }
        # With an Array
        when (ref eq 'ARRAY') {
            $inputs = $input
        }
        default {
            die "Unknown input: $input";
        }
    }

    my $storage = $self->_storage;

    $storage->start_learning();
    $self->_learn_one($_) for @$inputs;
    $storage->stop_learning();
    return;
}

sub _learn_one {
    my ($self, $input) = @_;
    my $engine  = $self->_engine;

    my $tokens = $self->_tokenizer->make_tokens($input);
    $engine->learn($tokens);

    return;
}

sub learn_reply {
    my ($self, $input) = @_;
    $self->learn($input);
    return $self->reply($input);
}

sub reply {
    my ($self, $input) = @_;

    my $storage   = $self->_storage;
    # start_training() hasn't been called so we can't guarentee that
    # the storage has been engaged at this point. This must be called
    # before ->_engine() is called anywhere to ensure that the
    # lazy-loading in the engine works.
    $storage->_engage() unless $storage->_engaged;

    my $engine    = $self->_engine;
    my $tokenizer = $self->_tokenizer;

    my $reply;
    if (defined $input) {
        my $tokens = $tokenizer->make_tokens($input);
        $reply = $engine->reply($tokens);
    }
    else {
        $reply = $engine->reply();
    }

    return unless defined $reply;
    return $tokenizer->make_output($reply);
}

sub stats {
    my ($self) = @_;

    return $self->_storage->totals();
}

sub DEMOLISH {
    my ($self) = @_;
    $self->save_on_exit if $self->{_storage} and $self->save;
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
    use Any::Moose;
    use Hailo;

    # Construct a new in-memory Hailo using the SQLite backend. See
    # backend documentation for other options.
    my $hailo = Hailo->new;

    # Various ways to learn
    my @train_this = ("I like big butts", "and I can not lie");
    $hailo->learn(\@train_this);
    $hailo->learn($_) for @train_this;

    # Heavy-duty training interface. Backends may drop some safety
    # features like journals or synchronous IO to train faster using
    # this mode.
    $hailo->train("megahal.trn");
    $hailo->train($filehandle);

    # Make the brain babble
    say $hailo->reply("hello good sir.");
    # Just say something at random
    say $hailo->reply();

=head1 DESCRIPTION

Hailo is a fast and lightweight markov engine intended to replace
L<AI::MegaHAL|AI::MegaHAL>. It has a L<Mouse|Mouse> (or
L<Moose|Moose>) based core with pluggable
L<storage|Hailo::Role::Storage>, L<tokenizer|Hailo::Role::Tokenizer>
and L<engine|Hailo::Role::Engine> backends.

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

=head1 Backends

Hailo supports pluggable L<storage|Hailo::Role::Storage> and
L<tokenizer|Hailo::Role::Tokenizer> backends, it also supports a
pluggable L<UI|Hailo::Role::UI> backend which is used by the L<hailo>
command-line utility.

=head2 Storage

Hailo can currently store its data in either a
L<SQLite|Hailo::Storage::SQLite>,
L<PostgreSQL|Hailo::Storage::PostgreSQL> or
L<MySQL|Hailo::Storage::MySQL> database. Some NoSQL backends were
supported in earlier versions, but they were removed as they had no
redeeming quality.

SQLite is the primary target for Hailo. It's much faster and uses less
resources than the other two. It's highly recommended that you use it.

See L<Hailo::Storage/"Comparison of backends"> for benchmarks showing
how the various backends compare under different workloads, and how
you can create your own.

=head2 Tokenizer

By default Hailo will use L<the word
tokenizer|Hailo::Tokenizer::Words> to split up input by whitespace,
taking into account things like quotes, sentence terminators and more.

There's also a L<the character
tokenizer|Hailo::Tokenizer::Chars>. It's not generally useful for a
conversation bot but can be used to e.g. generate new words given a
list of existing words.

=head1 UPGRADING

Hailo makes no promises about brains generated with earlier versions
being compatable with future version and due to the way Hailo works
there's no practical way to make that promise. Learning in Hailo is
lossy so an accurate conversion is impossible.

If you're maintaining a Hailo brain that you want to keep using you
should save the input you trained it on and re-train when you upgrade.

Hailo is always going to lose information present in the input you
give it. How input tokens get split up and saved to the storage
backend depends on the version of the tokenizer being used and how
that input gets saved to the database.

For instance if an earlier version of Hailo tokenized C<"foo+bar">
simply as C<"foo+bar"> but a later version split that up into
C<"foo", "+", "bar">, then an input of C<"foo+bar are my favorite
metasyntactic variables"> wouldn't take into account the existing
C<"foo+bar"> string in the database.

Tokenizer changes like this would cause the brains to accumulate
garbage and would leave other parts in a state they wouldn't otherwise
have gotten into.

There have been more drastic changes to the database format itself in
the past.

Having said all that the database format and the tokenizer are
relatively stable. At the time of writing 0.33 is the latest release
and it's compatable with brains down to at least 0.17. If you're
upgrading and there isn't a big notice about the storage format being
incompatable in the F<Changes> file your old brains will probably work
just fine.

=head1 ATTRIBUTES

=head2 C<brain>

The name of the brain (file name, database name) to use as storage.
There is no default. Whether this gets used at all depends on the
storage backend, currently only SQLite uses it.

=head2 C<save_on_exit>

A boolean value indicating whether Hailo should save its state before
its object gets destroyed. This defaults to true and will simply call
L<save|/save> at C<DEMOLISH> time.

=head2 C<order>

The Markov order (chain length) you want to use for an empty brain.
The default is 2.

=head2 C<engine_class>

=head2 C<storage_class>

=head2 C<tokenizer_class>

=head2 C<ui_class>

A a short name name of the class we use for the engine, storage,
tokenizer or ui backends.

By default this is B<Default> for the engine, B<SQLite> for storage,
B<Words> for the tokenizer and B<ReadLine> for the UI. The UI backend
is only used by the L<hailo> command-line interface.

You can only specify the short name of one of the packages Hailo
itself ships with. If you need another class then just prefix the
package with a plus (Catalyst style), e.g. C<+My::Foreign::Tokenizer>.

=head2 C<engine_args>

=head2 C<storage_args>

=head2 C<tokenizer_args>

=head2 C<ui_args>

A C<HashRef> of arguments for engine/storage/tokenizer/ui
backends. See the documentation for the backends for what sort of
arguments they accept.

=head1 METHODS

=head2 C<new>

This is the constructor. It accepts the attributes specified in
L</ATTRIBUTES>.

=head2 C<learn>

Takes a string or an array reference of strings and learns from them.

=head2 C<train>

Takes a filename, filehandle or array reference and learns from all its
lines. If a filename is passed, the file is assumed to be UTF-8 encoded.
Unlike L<C<learn>|/learn>, this method sacrifices some safety (disables
the database journal, fsyncs, etc) for speed while learning.

=head2 C<reply>

Takes an optional line of text and generates a reply that might be relevant.

=head2 C<learn_reply>

Takes a string argument, learns from it, and generates a reply that
might be relevant. This is equivalent to calling L<learn|/learn>
followed by L<reply|/reply>.

=head2 C<save>

Tells the underlying storage backend to L<save its
state|Hailo::Role::Storage/"save">, any arguments to this method will
be passed as-is to the backend.

=head2 C<stats>

Takes no arguments. Returns the number of tokens, expressions, previous
token links and next token links.

=head1 SUPPORT

You can join the IRC channel I<#hailo> on FreeNode if you have questions.

=head1 BUGS

Bugs, feature requests and other issues are tracked in L<Hailo's RT on
rt.cpan.org|https://rt.cpan.org/Dist/Display.html?Name=Hailo>

=head1 SEE ALSO

=over

=item * L<POE::Component::Hailo> - A non-blocking POE wrapper around Hailo

=item * L<POE::Component::IRC::Plugin::Hailo> - A Hailo IRC bot plugin

=item * L<http://github.com/hinrik/failo> - Failo, an IRC bot that uses Hailo

=item * L<http://github.com/bingos/gumbybrain> - GumbyBRAIN, a more famous IRC bot that uses Hailo

=item * L<Hailo::UI::Web> - A L<Catalyst> and jQuery powered web
interface to Hailo available at L<hailo.nix.is|http://hailo.nix.is>
and as L<hailo-ui-web|http://github.com/avar/hailo-ui-web> on
L<GitHub|http://github.com>

=item * L<HALBot> - Another L<Catalyst> Dojo powered web interface to
Hailo available at L<bifurcat.es|http://bifurcat.es/> and as
L<halbot-on-the-web|http://gitorious.org/halbot-on-the-web/halbot-on-the-web>
at L<gitorious|http://gitorious.org>

=item * L<http://github.com/pteichman/cobe> - cobe, a Python port of MegaHAL "inspired by the success of Hailo"

=back

=head1 LINKS

=over

=item * L<hailo.org|http://hailo.org> - Hailo's website

=item * L<http://bit.ly/hailo_rewrite_of_megahal> - Hailo: A Perl rewrite of
MegaHAL, A blog posting about the motivation behind Hailo

=item * L<http://blogs.perl.org/users/aevar_arnfjor_bjarmason/hailo/> -
More blog posts about Hailo on E<AElig>var ArnfjE<ouml>rE<eth>
Bjarmason's L<blogs.perl.org|http://blogs.perl.org> blog

=item * Hailo on L<freshmeat|http://freshmeat.net/projects/hailo> and
L<ohloh|https://www.ohloh.net/p/hailo>

=back

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
