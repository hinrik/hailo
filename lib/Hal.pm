package Hal;

use strict;
use warnings;

our $DEFAULT_ORDER   = 5;
our $DEFAULT_BACKEND = 'Perl';
our $DEFAULT_TOKE    = 'Generic';

our $VERSION = '0.01';

sub new {
    my ($package, %args) = @_;
    my $self = bless \%args, $package;
    
    if (!defined $self->{storage} || $self->{storage} !~ /^\w+$/) {
        $self->{storage} = $DEFAULT_BACKEND;
    }
    if (!defined $self->{tokenizer} || $self->{tokenizer} !~ /^\w+$/) {
        $self->{tokenizer} = $DEFAULT_TOKE;
    }
    if (!defined $self->{order} || $self->{order} !~ /^\d+$/) {
        $self->{order} = $DEFAULT_ORDER;
    }
    
    $self->_create_storage();
    $self->_create_tokenizer();

    return $self;
}

sub save {
    my ($self) = @_;
    $self->{storage}->save();
    return;
}

sub _create_storage {
    my ($self) = @_;
    
    my $storage = "Hal::Storage::$self->{storage}";
    eval "require $storage";
    $self->{storage} = $storage->new(
        file  => $self->{file},
        order => $self->{order},
    );

    delete $self->{file};
    delete $self->{order};

    return;
}

sub _create_tokenizer {
    my ($self) = @_;
    
    my $tokenizer = "Hal::Tokenizer::$self->{tokenizer}";
    eval "require $tokenizer";
    $self->{tokenizer} = $tokenizer->new();

    return;
}

sub train {
    my ($self, $filename) = @_;

    open my $fh, '<:encoding(utf8)', $filename or die "Can't open file '$filename': $!\n";
    while (my $line = <$fh>) {
        chomp $line;
        $self->learn($line);
    }
    close $fh;
    return;
}

sub learn {
    my $self = shift;
    my @tokens = $self->{tokenizer}->make_tokens(shift);
    my $storage = $self->{storage};

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
    my $storage = $self->{storage};
    my $toke = $self->{tokenizer};
    
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
    my $storage = $self->{storage};

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
    my $storage = $self->{storage};

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

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
