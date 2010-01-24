package Hal;
use 5.010;
use Moose;
use MooseX::Types 
    -declare => [ qw( OrderInt ) ];
use MooseX::Types::Moose qw/Int Str/;
use MooseX::Types::Path::Class qw(File);
use namespace::clean -except => 'meta';
with qw(MooseX::Getopt);

our $VERSION = '0.02';

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

subtype OrderInt,
    as Int,
    where { $_ > 0 and $_ < 50 },
    message { "Order outsite 1..50 will explode the database" };

has order         => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "o",
    cmd_flag      => "order",
    documentation => "Markov order",
    isa           => OrderInt,
    is            => "ro",
    default       => 5,
);

has brain_file => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "b",
    cmd_flag      => "brain",
    documentation => "Load/save brain to/from FILE",
    isa           => Str,
    is            => "ro",
);

has storage_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "S",
    cmd_flag      => "storage",
    documentation => "Use storage CLASS",
    isa           => Str,
    is            => "ro",
    default       => "Perl",
);

has tokenizer_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "T",
    cmd_flag      => "tokenizer",
    documentation => "Use tokenizer CLASS",
    isa           => Str,
    is            => "ro",
    default       => "Generic",
);

has storage_obj => (
    traits      => [qw(NoGetopt)],
    lazy_build  => 1,
    is          => 'ro',
);

sub _build_storage_obj {
    my ($self) = @_;
    
    my $storage_class = $self->storage_class;
    my $storage = "Hal::Storage::$storage_class";
    eval "require $storage";
    die $@ if $@;

    return $storage->new(
        file  => $self->brain_file,
        order => $self->order,
    );
}

has tokenizer_obj => (
    traits      => [qw(NoGetopt)],
    lazy_build  => 1,
    is          => 'ro',
);

sub _build_tokenizer_obj {
    my ($self) = @_;

    my $tokenizer_class = $self->tokenizer_class;
    
    my $tokenizer = "Hal::Tokenizer::$tokenizer_class";
    eval "require $tokenizer";
    die $@ if $@;

    return $tokenizer->new();
}

sub run {
    my $self = shift;

    $self->train($self->train_file) if $self->train_file;
    $self->learn($self->learn_str)  if $self->learn_str;
    $self->save()                   if $self->brain_file;

    if (defined $self->reply_str) {
        my $answer = $self->reply($self->reply_str);
        die "I don't know enough to answer you yet.\n" if !defined $answer;
        say $answer;
    }
    return;
}

sub save {
    my ($self) = @_;
    $self->storage_obj->save();
    return;
}

sub train {
    my ($self) = @_;

    $self->storage_obj->start_training();
    my $filename = $self->train_file;

    open my $fh, '<:encoding(utf8)', $filename or die "Can't open file '$filename': $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        $self->learn($line);
    }
    close $fh;
    $self->storage_obj->stop_training();
    return;
}

sub learn {
    my ($self, $input) = @_;

    # a newline functions as beginning-of-string or end-of-string
    $input = "\n$input\n";
    my @tokens = $self->tokenizer_obj->make_tokens($input);

    my $storage = $self->storage_obj;
    my $order = $storage->order;

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
    my $storage = $self->storage_obj;
    my $order = $storage->order;
    my $toke = $self->tokenizer_obj;
    
    my @tokens = $toke->make_tokens($input);
    my @key_tokens = grep { $storage->token_exists($_) } $toke->find_key_tokens(@tokens);
    return if !@key_tokens;
    my @current_key_tokens;
    my $key_token = shift @key_tokens;

    my @middle_expr = $storage->random_expr($key_token);
    my @reply = @middle_expr;
    
    my @current_expr = @middle_expr;

    # construct the end of the reply
    while ($current_expr[-1] ne "\n") {
        my $next_token = $self->_next_token(\@current_expr, \@current_key_tokens);
        push @reply, $next_token;
        @current_expr = (@current_expr[1 .. $order-1], $next_token);
    }
    
    # reuse the key tokens
    @current_key_tokens = @key_tokens;

    @current_expr = @middle_expr;

    # construct the beginning of the reply
    while ($current_expr[0] ne "\n") {
        my $prev_token = $self->_prev_token(\@current_expr, \@current_key_tokens);
        @reply = ($prev_token, @reply);
        @current_expr = ($prev_token, @current_expr[0 .. $order-2]);
    }

    return $toke->make_output(@reply);
}

# return a succeeding token, preferring key tokens, otherwise random
# removes corresponding element from $key_tokens array if used
sub _next_token {
    my ($self, $expr, $key_tokens) = @_;
    my $storage = $self->storage_obj;

    my @next_tokens = $storage->next_tokens($expr);
    my %next = map { +$_ => 1 } @next_tokens;

    for my $i (0 .. $#{ $key_tokens }) {
        next if !exists $next{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens = keys %next;
    return @novel_tokens[rand @novel_tokens];
}

# return a preceding token, preferring key tokens, otherwise random
# removes corresponding element from $key_tokens array if used
sub _prev_token {
    my ($self, $expr, $key_tokens) = @_;
    my $storage = $self->storage_obj;

    my @prev_tokens = $storage->prev_tokens($expr);
    my %prev = map { +$_ => 1 } @prev_tokens;

    for my $i (0 .. $#{ $key_tokens }) {
        next if !exists $prev{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens = keys %prev;
    return @novel_tokens[rand @novel_tokens];
}

1;

=encoding utf8

=head1 NAME

Hal - A conversation bot using Markov chains

=head1 DESCRIPTION

This is a chat bot which utilizes Markov chains. It is loosely based on a
C program called MegaHAL.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 METHODS

=head2 C<new>

Creates a new Hal object. Takes the following optional parameters:

B<'file'>, path to the file you want your brain to be saved/loaded.

B<'order'>, the Markov order of the bot (default: 5).

B<'storage'>, the storage backend to use (default 'Perl').

B<'tokenizer'>, the tokenizer to use (default 'Generic').

=head2 C<learn>

Takes a line of next as input and learns from it.

=head2 C<train>

Takes a filename and calls L<C<learn>|/learn> on all its lines.

=head2 C<reply>

Takes a line of text and generates a reply that might be relevant.

=head2 C<save>

Tells the underlying storage backend to save its state.

=head2 C<run>

Run the application according to the command line arguments.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
