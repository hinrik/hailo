package Hailo::Tokenizer::Words;
use 5.010;
use utf8;
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use namespace::clean -except => 'meta';

our $VERSION = '0.20';

with qw(Hailo::Role::Arguments
        Hailo::Role::Tokenizer);

# tokenization
my $DECIMAL    = qr/[.,]/;
my $NUMBER     = qr/$DECIMAL?\d+(?:$DECIMAL\d+)*/;
my $APOSTROPHE = qr/['’]/;
my $APOST_WORD = qr/\w+(?:$APOSTROPHE\w+)*/;
my $WORD       = qr/$NUMBER|$APOST_WORD/;

# capitalization
my $OPEN_QUOTE  = qr/['"‘“„«»「『‹‚]/;
my $CLOSE_QUOTE = qr/['"’“”«»」』›‘]/;
my $TERMINATOR  = qr/(?:[?!‽]+|(?<!\.)\.)/;
my $ADDRESS     = qr/:/;
my $PUNCTUATION = qr/[?!‽,;.:]/;
my $WORD_SPLIT  = qr{[-/](?![-/])};
my $BOUNDARY    = qr/\s*$CLOSE_QUOTE?\s*(?:$TERMINATOR|$ADDRESS)\s+$OPEN_QUOTE?\s*/;

# we want to capitalize words that come after "On example.com?"
# or "You mean 3.2?", but not "Yes, e.g."
my $DOTTED_STRICT = qr/\w+(?:$DECIMAL(?:\d+|\w{2,}))?/;
my $WORD_STRICT   = qr/$DOTTED_STRICT(?:$APOSTROPHE$DOTTED_STRICT)*/;

# input -> tokens
sub make_tokens {
    my ($self, $line) = @_;

    my @tokens;
    my @chunks = split /\s+/, $line;
    for my $chunk (@chunks) {

        my $got_word = 0;
        while (length $chunk) {
            if (my ($word) = $chunk =~ /^($WORD)/) {
                $chunk =~ s/^\Q$word//;
                $word = lc($word) if $word ne uc($word);
                push @tokens, [0, $word];
                $got_word = 1;
            }
            elsif (my ($non_word) = $chunk =~ /^(\W+)/) {
                $chunk =~ s/^\Q$non_word//;
                $non_word = lc($non_word) if $non_word ne uc($non_word);

                my $spacing = 0;
                if ($got_word) {
                    $spacing = length $chunk ? 3 : 2;
                }
                elsif (length $chunk) {
                    $spacing = 1;
                }

                push @tokens, [$spacing, $non_word];
            }
        }
    }
    return \@tokens;
}

# tokens -> output
sub make_output {
    my ($self, $tokens) = @_;
    my $reply = '';

    for my $pos (0 .. $#{ $tokens }) {
        my ($spacing, $text) = @{ $tokens->[$pos] };
        $reply .= $text;

        # append whitespace if this is not a prefix token or infix token,
        # and this is not the last token, and the next token is not
        # a postfix/infix token
        if ($pos != $#{ $tokens }
            && $spacing !~ /[13]/
            && !($pos < $#{ $tokens } && $tokens->[$pos+1][0] =~ /[23]/)) {
            $reply .= ' ';
        }
    }

    # capitalize the first word
    $reply =~ s/^$TERMINATOR?\s*$OPEN_QUOTE?\s*\K($WORD)(?=(?:$TERMINATOR+|$ADDRESS|$PUNCTUATION+)?(?:$WORD_SPLIT| |$))/\u$1/;

    # capitalize the second word
    $reply =~ s/^$TERMINATOR?\s*$OPEN_QUOTE?\s*$WORD(?:\s*(?:$TERMINATOR|$ADDRESS)\s+)\K($WORD)/\u$1/;

    # capitalize all other words after word boundaries
    # we do it in two passes because we need to match two words at a time
    $reply =~ s/ $OPEN_QUOTE?\s*$WORD_STRICT$BOUNDARY\K($WORD)/\x1B\u$1\x1B/g;
    $reply =~ s/\x1B$WORD_STRICT\x1B$BOUNDARY\K($WORD)/\u$1/g;
    $reply =~ s/\x1B//g;

    # end paragraphs with a period when it makes sense
    $reply =~ s/(?:$WORD_SPLIT| |^)$OPEN_QUOTE?$WORD$CLOSE_QUOTE?\K$/./;

    # capitalize I
    $reply =~ s{ \Ki(?=$PUNCTUATION| |$APOSTROPHE)}{I}g;

    return $reply;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Tokenizer::Words - A tokenizer for L<Hailo|Hailo> which splits
on whitespace, mostly.

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
