package Hailo;

use 5.010;
use Moose;
use MooseX::Types -declare => [qw(OrderInt)];
use MooseX::Types::Moose qw/Int Str Bool/;
use MooseX::Types::Path::Class qw(File);
use Term::ProgressBar 2.00;
use File::CountLines qw(count_lines);
use Time::HiRes qw(gettimeofday tv_interval);
use namespace::clean -except => [ qw(meta
                                     count_lines
                                     gettimeofday
                                     tv_interval) ];

our $VERSION = '0.01';

subtype OrderInt,
    as Int,
    where { $_ > 0 and $_ < 50 },
    message { "Order outside 1..50 will explode the database" };

has print_version => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'v',
    cmd_flag      => 'version',
    documentation => 'Print version and exit',
    isa           => Bool,
    is            => 'ro',
);

has learn_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "l",
    cmd_flag      => "learn",
    documentation => "Learn from STRING",
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
    isa           => OrderInt,
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

has boundary_token => (
    traits        => [qw(Getopt)],
    cmd_aliases   => 'B',
    cmd_flag      => 'boundary',
    documentation => "Token used to signify a paragraph boundary",
    isa           => Str,
    is            => 'ro',
    default       => "\012",
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

sub _build__storage_obj {
    my ($self) = @_;
    
    my $storage_class = $self->storage_class;
    my $storage = "Hailo::Storage::$storage_class";
    eval "require $storage";
    die $@ if $@;

    return $storage->new(
        (defined $self->brain_resource
            ? (brain => $self->brain_resource)
            : ()
        ),
        order => $self->order,
    );
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
    my $storage = $self->_storage_obj;

    if ($self->print_version) {
        say "hailo $VERSION";
        exit;
    }

    if (defined $self->train_file) {
        $storage->start_training();
        $self->train($self->train_file);
        $storage->stop_training();
    }

    if (defined $self->learn_str) {
        $storage->start_learning();
        $self->learn($self->learn_str);
        $storage->start_learning();
    }

    $self->save() if defined $self->brain_resource;

    if (defined $self->reply_str) {
        my $answer = $self->reply($self->reply_str);
        die "I don't know enough to answer you yet.\n" if !defined $answer;
        say $answer;
    }
    return;
}

sub save {
    my ($self) = @_;
    $self->_storage_obj->save();
    return;
}

sub train {
    my ($self) = @_;

    $self->_storage_obj->start_training();
    my $filename = $self->train_file;

    open my $fh, '<:encoding(utf8)', $filename or die "Can't open file '$filename': $!\n";
    $self->_train_progress($fh, $filename);
    close $fh;
    $self->_storage_obj->stop_training();
    return;
}

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
        $self->learn($line);

        $next_update = $progress->update($i) if $i++ >= $next_update;
    }

    $progress->update($lines) if $lines >= $next_update;
    my $elapsed = tv_interval($start_time);
    say "Imported in $elapsed seconds";

    return;
}

sub learn {
    my ($self, $input) = @_;
    my $storage  = $self->_storage_obj;
    my $order    = $storage->order;
    my $boundary = $self->boundary_token;

    # add boundary tokens
    $input = "$boundary$input$boundary";
    my @tokens = $self->_tokenizer_obj->make_tokens($input);

    # only learn from inputs which are long enough
    return if @tokens < $order;

    for my $i (0 .. @tokens - $order) {
        my @expr = map { $tokens[$_] } ($i .. $i+$order-1);

        my ($next_token, $prev_token);
        $next_token = $tokens[$i+$order] if $i < @tokens - $order;
        $prev_token = $tokens[$i-1] if $i > 0;

        # store the current expression
        $storage->add_expr(
            tokens     => \@expr,
            next_token => $next_token,
            prev_token => $prev_token,
        );
    }

    return;
}

sub reply {
    my ($self, $input) = @_;
    my $storage  = $self->_storage_obj;
    my $order    = $storage->order;
    my $toke     = $self->_tokenizer_obj;
    my $boundary = $self->boundary_token;
    
    my @tokens = $toke->make_tokens($input);
    my @key_tokens = grep { $storage->token_exists($_) } $toke->find_key_tokens(@tokens);
    return if !@key_tokens;
    my @current_key_tokens;
    my $key_token = shift @key_tokens;

    my @middle_expr = $storage->random_expr($key_token);
    my @reply = @middle_expr;
    
    my @current_expr = @middle_expr;

    # construct the end of the reply
    while ($current_expr[-1] ne $boundary) {
        my $next_tokens = $storage->next_tokens(\@current_expr);
        my $next_token = $self->_pos_token($next_tokens, \@current_key_tokens);
        push @reply, $next_token;
        @current_expr = (@current_expr[1 .. $order-1], $next_token);
    }
    
    # reuse the key tokens
    @current_key_tokens = @key_tokens;

    @current_expr = @middle_expr;

    # construct the beginning of the reply
    while ($current_expr[0] ne $boundary) {
        my $prev_tokens = $storage->prev_tokens(\@current_expr);
        my $prev_token = $self->_pos_token($prev_tokens, \@current_key_tokens);
        @reply = ($prev_token, @reply);
        @current_expr = ($prev_token, @current_expr[0 .. $order-2]);
    }

    # remove boundary tokens
    shift @reply;
    pop @reply;

    return $toke->make_output(@reply);
}

sub _pos_token {
    my ($self, $next_tokens, $key_tokens) = @_;
    my $storage = $self->_storage_obj;

    for my $i (0 .. $#{ $key_tokens }) {
        next if !exists $next_tokens->{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens;
    while (my ($token, $count) = each %$next_tokens) {
        push @novel_tokens, ($token) x $count;
    }
    return @novel_tokens[rand @novel_tokens];
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo - A pluggable Markov engine analogous to MegaHAL

=head1 SYNOPSIS

    use 5.10.0;
    use Hailo;

    my $hailo = Hailo->new(
        # Or Pg, or Perl ...
        storage_class  => 'SQLite',
        brain_resource => 'brain.storable'
    );

    while (<>) {
        $hailo->learn($_);
        say $hailo->reply($_);
    }

=head1 DESCRIPTION

Hailo is a fast and pluggable markov engine intended to replace
L<AI::MegaHAL>, it has a lightweight L<Moose>-based core with
pluggable L<storage backends|Hailo::Role::Storage> and
L<tokenizers|Hailo::Role::Tokenizer>. It's faster than MegaHAL and can
handle huge brains easily with the recommended L<SQLite
backend|Hailo::Storage::SQLite>.

It can be used, amongst other things, to implement IRC chat bots with
L<POE::Component::IRC>.

=head1 ATTRIBUTES

=head2 C<brain_resource>

The name of the resource (file name, database name) to use as storage.
There is no default.

=head2 C<order>

The Markov order (chain length) you want to use for an empty brain.
The default is 5.

=head2 C<storage>

The storage backend to use. Default: 'SQLite'.

=head2 C<tokenizer>

The tokenizer to use. Default: 'Words';

=head2 C<boundary_token>

The token used to signify a paragraph boundary. Has to be something that
would never appear in your inputs. Defaults to C<"\012">.

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

=head2 C<save>

Tells the underlying storage backend to save its state.

=head1 ETYMOLOGY

I<Hailo> is a portmanteau of I<Hal> and L<I<failo>|http://identi.ca/failo>

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
