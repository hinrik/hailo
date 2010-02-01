package Hailo::Tokenizer::Words;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use List::MoreUtils qw<uniq>;
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

with qw(Hailo::Role::Generic
        Hailo::Role::Tokenizer);

my $APOSTROPHE    = qr/['’]/;
my $DOTTED_WORD   = qr/\w+(?:\.\w+)?/;
my $WORD          = qr/$DOTTED_WORD(?:$APOSTROPHE$DOTTED_WORD)*/;
my $TOKEN         = qr/(?:$WORD| +|.)/s;
my $OPEN_QUOTE    = qr/['"‘“„«»「『‹‚]/;
my $CLOSE_QUOTE   = qr/['"’«»“”」』›‘]/;
my $TERMINATOR    = qr/(?:[?!‽]+|(?<!\.)\.)/;
my $ADDRESS       = qr/:/;
my $BOUNDARY      = qr/\s*$CLOSE_QUOTE?\s*(?:$TERMINATOR|$ADDRESS)\s+$OPEN_QUOTE?\s*/;
my $INTERESTING   = qr/\S/;

# these are only used in capitalization, because we want to capitalize words
# that come after "On example.com?" or "You mean 3.2?", but not "Yes, e.g."
my $DOTTED_STRICT = qr/\w+(?:\.(?:\d+|\w{2,}))?/;
my $WORD_STRICT   = qr/$DOTTED_STRICT(?:$APOSTROPHE$DOTTED_STRICT)*/;

# input -> tokens
sub make_tokens {
    my ($self, $line) = @_;
    my (@tokens) = $line =~ /($TOKEN)/gs;

    # lower-case tokens except those which are ALL UPPERCASE
    @tokens = map { $_ ne uc($_) ? lc($_) : $_ } @tokens;
    return @tokens;
}

# return a list of key tokens
sub find_key_tokens {
    my $self = shift;
    
    # remove duplicates and return the interesting ones
    return grep { /$INTERESTING/ } uniq(@_);
}

# tokens -> output
sub make_output {
    my $self = shift;
    my $string = join '', @_;

    # capitalize the first word
    $string =~ s/^$TERMINATOR?\s*$OPEN_QUOTE?\s*\K($WORD)/\u$1/;

    # capitalize the second word
    $string =~ s/^$TERMINATOR?\s*$OPEN_QUOTE?\s*$WORD(?:\s*(?:$TERMINATOR|$ADDRESS)\s+)\K($WORD)/\u$1/;

    # capitalize all other words after word boundaries
    # we do it in two passes because we need to match two words at a time
    $string =~ s/ $WORD_STRICT$BOUNDARY\K($WORD)/\x1B\u$1\x1B/g;
    $string =~ s/\x1B$WORD_STRICT\x1B$BOUNDARY\K($WORD)/\u$1/g;
    $string =~ s/\x1B//g;

    # end paragraphs with a period when it makes sense
    $string =~ s/ $WORD\K$/./;

    # capitalize the word 'I'
    $string =~ s{(?<= )\bi\b}{I}g;

    return $string;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Tokenizer::Words - A word tokenizer for L<Hailo|Hailo>

=head1 DESCRIPTION

This tokenizer does its best to handle various languages. It knows about most
apostrophes, quotes, and sentence terminators.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
