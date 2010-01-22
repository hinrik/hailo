package Hal;
use 5.010;
use Moose;
use namespace::clean -except => 'meta';

with qw(MooseX::Getopt);

our $VERSION = '0.02';

has learn_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "l",
    cmd_flag      => "learn",
    documentation => "Learn from STRING",
    isa           => "Str",
    is            => "ro",
);

has train_file => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "t",
    cmd_flag      => "train",
    documentation => "Learn from all the lines in FILE",
    isa           => "Str",
    is            => "ro",
);

has reply_str => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "r",
    cmd_flag      => "reply",
    documentation => "Reply to STRING",
    isa           => "Str",
    is            => "ro",
);

has order         => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "o",
    cmd_flag      => "order",
    documentation => "Markov order",
    isa           => "Int",
    is            => "ro",
    default       => 5,
);

has brain_file => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "b",
    cmd_flag      => "brain",
    documentation => "Load/save brain to/from FILE",
    isa           => "Str",
    is            => "ro",
);

has storage_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "S",
    cmd_flag      => "storage",
    documentation => "Use storage CLASS",
    isa           => "Str",
    is            => "ro",
    default       => "Perl",
);

has tokenizer_class => (
    traits        => [qw(Getopt)],
    cmd_aliases   => "S",
    cmd_flag      => "storage",
    documentation => "Use tokenizer CLASS",
    isa           => "Str",
    is            => "ro",
    default       => "Generic",
);

has storage => (
    traits      => [qw(NoGetopt)],
    lazy_build  => 1,
    is          => 'ro',
);

sub _build_storage {
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

has tokenizer => (
    traits      => [qw(NoGetopt)],
    lazy_build  => 1,
    is          => 'ro',
);

sub _build_tokenizer {
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
    $self->storage->save();
    return;
}

sub train {
    my ($self) = @_;

    my $filename = $self->train_file;

    open my $fh, '<:encoding(utf8)', $filename or die "Can't open file '$filename': $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        $self->learn($line);
    }
    close $fh;
    return;
}

sub learn {
    my ($self, $str) = @_;
    my @tokens = $self->tokenizer->make_tokens($str);
    my $storage = $self->storage;

    # only learn from inputs which are long enough
    return if @tokens < $storage->order();

    for (my $i = 0; $i <= @tokens - $storage->order(); $i++) {
        my %blurb;
        $blurb{can_start} = 1 if $i == 0;
        $blurb{can_end}   = 1 if $i == @tokens - $storage->order();
        $blurb{tokens}    = [ map { $tokens[$_] } ($i .. $i+$storage->order()-1) ];

        my ($next_token, $prev_token);
        $next_token = $tokens[$i+$storage->order()] if $i < @tokens - $storage->order();
        $prev_token = $tokens[$i-1] if $i > 0;

        # tell the storage about the current blurb
        $storage->add_blurb(
            blurb      => \%blurb,
            next_token => $next_token,
            prev_token => $prev_token,
        );
    }

    return;
}

sub reply {
    my ($self, $input) = @_;
    my $storage = $self->storage;
    my $toke = $self->tokenizer;
    
    my @tokens = $toke->make_tokens($input);
    my @key_tokens = grep { $storage->token_exists($_) } $toke->find_key_tokens(@tokens);
    return if !@key_tokens;
    my @current_key_tokens;
    my $key_token = shift @key_tokens;

    my $middle_blurb = $storage->random_blurb($key_token);
    my $reply = join '', @{ $middle_blurb->{tokens} };
    
    my $current_blurb = $middle_blurb;

    # construct the end of the reply
    while (!$current_blurb->{can_end}) {
        my $next_token = $self->_next_token($current_blurb, \@current_key_tokens);
        #my %next_tokens = keys %{ $storage->next_tokens($current_blurb) };
        #my $next_token = @next_tokens[rand @next_tokens];
        
        $reply .= $next_token;
        my @new_tokens = (@{ $current_blurb->{tokens} }[1..$storage->order()-1], $next_token);
        $current_blurb = $storage->find_blurb(@new_tokens);
    }
    
    # reuse the key tokens
    @current_key_tokens = @key_tokens;

    $current_blurb = $middle_blurb;

    # construct the beginning of the reply
    while (!$current_blurb->{can_start}) {
        my $prev_token = $self->_prev_token($current_blurb, \@current_key_tokens);
        #my @prev_tokens = keys %{ $storage->prev_tokens($current_blurb) };
        #my $prev_token = @prev_tokens[rand @prev_tokens];
        
        $reply = "$prev_token$reply";
        my @new_tokens = ($prev_token, @{ $current_blurb->{tokens} }[0..$storage->order()-2]);
        $current_blurb = $storage->find_blurb(@new_tokens);
    }

   return $toke->make_output($reply);
}

# return a succeeding token, preferring key tokens, otherwise random
# removes corresponding element from $key_tokens array if used
sub _next_token {
    my ($self, $blurb, $key_tokens) = @_;
    my $storage = $self->storage;

    my $next_tokens = $storage->next_tokens($blurb);

    for (my $i = 0; $i < @$key_tokens; $i++) {
        next if !exists $next_tokens->{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens = keys %$next_tokens;
    return @novel_tokens[rand @novel_tokens];
}

# return a preceding token, preferring key tokens, otherwise random
# removes corresponding element from $key_tokens array if used
sub _prev_token {
    my ($self, $blurb, $key_tokens) = @_;
    my $storage = $self->storage;

    my $prev_tokens = $storage->prev_tokens($blurb);

    for (my $i = 0; $i < @$key_tokens; $i++) {
        next if !exists $prev_tokens->{ @$key_tokens[$i] };
        return splice @$key_tokens, $i, 1;
    }

    my @novel_tokens = keys %$prev_tokens;
    return @novel_tokens[rand @novel_tokens];
}


1;

=encoding utf8

=head1 NAME

Hal - A Markov bot

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
