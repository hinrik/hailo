package Hailo::Tokenizer::Words;

use 5.010;
use utf8;
use Any::Moose;
use Any::Moose 'X::StrictConstructor';
use Regexp::Common qw/ URI /;
use namespace::clean -except => 'meta';

with qw(Hailo::Role::Arguments
        Hailo::Role::Tokenizer);

# tokenization
my $DECIMAL    = qr/[.,]/;
my $NUMBER     = qr/$DECIMAL?\d+(?:$DECIMAL\d+)*/;
my $APOSTROPHE = qr/['’´]/;
my $APOST_WORD = qr/[[:alpha:]]+(?:$APOSTROPHE(?:[[:alpha:]]+))+/;
my $TWAT_NAME  = qr/ \@ [A-Za-z0-9_]+ /x;
my $PLAIN_WORD = qr/\w+/;
my $WORD_TYPES = qr/$NUMBER|$APOST_WORD|$PLAIN_WORD/;
my $WORD       = qr/$WORD_TYPES(?:-$WORD_TYPES)*/;
my $MIXED_CASE = qr/ \p{Lower}+ \p{Upper} /x;
my $UPPER_NONW = qr/^ \p{Upper}{2,} \W+ \p{Lower}+ $/x;

# capitalization
# The rest of the regexes are pretty hairy. The goal here is to catch the
# most common cases where a word should be capitalized. We try hard to
# guard against capitalizing things which don't look like proper words.
# Examples include URLs and code snippets.
my $OPEN_QUOTE  = qr/['"‘“„«»「『‹‚]/;
my $CLOSE_QUOTE = qr/['"’“”«»」』›‘]/;
my $TERMINATOR  = qr/(?:[?!‽]+|(?<!\.)\.)/;
my $ADDRESS     = qr/:/;
my $PUNCTUATION = qr/[?!‽,;.:]/;
my $BOUNDARY    = qr/$CLOSE_QUOTE?(?:\s*$TERMINATOR|$ADDRESS)\s+$OPEN_QUOTE?\s*/;
my $SPLIT_WORD  = qr{$WORD(?:/$WORD)?(?=$PUNCTUATION(?: |$)|$CLOSE_QUOTE|$TERMINATOR| |$)};

# we want to capitalize words that come after "On example.com?"
# or "You mean 3.2?", but not "Yes, e.g."
my $DOTTED_STRICT = qr/$WORD(?:$DECIMAL(?:\d+|\w{2,}))?/;
my $WORD_STRICT   = qr/$DOTTED_STRICT(?:$APOSTROPHE$DOTTED_STRICT)*/;

# input -> tokens
sub make_tokens {
    my ($self, $line) = @_;

    my @tokens;
    my @chunks = split /\s+/, $line;

    # process all whitespace-delimited chunks
    for my $chunk (@chunks) {
        my $got_word;

        while (length $chunk) {
            # urls
            if ($chunk =~ s/ ^ (?<uri> $RE{URI} ) //xo) {
                push @tokens, [$self->{_spacing_normal}, $+{uri}];
                $got_word = 1;
            }
            # Twitter names
            elsif ($chunk =~ s/ ^ (?<twat> $TWAT_NAME ) //xo) {
                # Names on Twitter/Identi.ca can only match
                # @[A-Za-z0-9_]+. I tested this on ~800k Twatterhose
                # names.
                push @tokens, [$self->{_spacing_normal}, $+{twat}];
                $got_word = 1;
            }
            # normal words
            elsif ($chunk =~ s/ ^ (?<word> $WORD )(?! $WORD ) //xo) {
                my $word = $+{word};
                # Maybe preserve the casing of this word
                $word = lc $word
                    if $word ne uc $word
                       # Mixed-case words like "WoW"
                       and $word !~ $MIXED_CASE
                       # Words that are upper case followed by a non-word character.
                       # {2,} so it doesn't match I'm
                       and $word !~ $UPPER_NONW;

                push @tokens, [$self->{_spacing_normal}, $word];
                $got_word = 1;
            }
            # everything else
            elsif (my ($non_word) = $chunk =~ s/ ^ (?<non_word> \W+ ) //xo) {
                my $non_word = $+{non_word};

                # lowercase it if it's not all-uppercase
                $non_word = lc($non_word) if $non_word ne uc($non_word);

                my $spacing = $self->{_spacing_normal};

                # was the previous token a word?
                if ($got_word) {
                    $spacing = length $chunk
                        ? $self->{_spacing_infix}
                        : $self->{_spacing_postfix};
                }
                # do we still have more tokens?
                elsif (length $chunk) {
                    $spacing = $self->{_spacing_prefix};
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
            && $spacing != $self->{_spacing_prefix}
            && $spacing != $self->{_spacing_infix}
            && !($pos < $#{ $tokens }
                && ($tokens->[$pos+1][0] == $self->{_spacing_postfix}
                || $tokens->[$pos+1][0] == $self->{_spacing_infix})
                )
            ) {
            $reply .= ' ';
        }
    }

    # capitalize the first word
    $reply =~ s/^\s*$OPEN_QUOTE?\s*\K($SPLIT_WORD)(?=(?:$TERMINATOR+|$ADDRESS|$PUNCTUATION+)?\b)/\u$1/o;

    # capitalize the second word
    $reply =~ s/^\s*$OPEN_QUOTE?\s*$SPLIT_WORD(?:(?:\s*$TERMINATOR|$ADDRESS)\s+)\K($SPLIT_WORD)/\u$1/o;

    # capitalize all other words after word boundaries
    # we do it in two passes because we need to match two words at a time
    $reply =~ s/ $OPEN_QUOTE?\s*$WORD_STRICT$BOUNDARY\K($SPLIT_WORD)/\x1B\u$1\x1B/go;
    $reply =~ s/\x1B$WORD_STRICT\x1B$BOUNDARY\K($SPLIT_WORD)/\u$1/go;
    $reply =~ s/\x1B//go;

    # end paragraphs with a period when it makes sense
    $reply =~ s/(?: |^)$OPEN_QUOTE?$SPLIT_WORD$CLOSE_QUOTE?\K$/./o;

    # capitalize I'm, I've...
    $reply =~ s{(?: |$OPEN_QUOTE)\Ki(?=$APOSTROPHE(?:[[:alpha:]]))}{I}go;

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
