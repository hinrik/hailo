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
my $NON_WORD   = qr/[^_\d[:alpha:]]+/;
my $PLAIN_WORD = qr/[_[:alpha:]]+/;
my $ALPHA_WORD = qr/$APOST_WORD|$PLAIN_WORD/;
my $WORD_TYPES = qr/$NUMBER|$ALPHA_WORD/;
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
my $LOOSE_WORD  = qr/(?:$NUMBER|$APOST_WORD|\w+)(?:-(?:$NUMBER|$APOST_WORD|\w+))*/;
my $SPLIT_WORD  = qr{$LOOSE_WORD(?:/$LOOSE_WORD)?(?=$PUNCTUATION(?: |$)|$CLOSE_QUOTE|$TERMINATOR| |$)};

# we want to capitalize words that come after "On example.com?"
# or "You mean 3.2?", but not "Yes, e.g."
my $DOTTED_STRICT = qr/$LOOSE_WORD(?:$DECIMAL(?:\d+|\w{2,}))?/;
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
            # We convert it to ASCII and then look for a URI because $RE{URI}
            # from Regexp::Common doesn't support non-ASCII domain names
            my $ascii = $chunk;
            $ascii =~ s/[^[:ascii:]]/a/g;

            # URIs
            if ($ascii =~ / ^ $RE{URI} /xo) {
                my $uri_end = $+[0];
                my $uri = substr $chunk, 0, $uri_end;
                $chunk =~ s/^\Q$uri//;

                push @tokens, [$self->{_spacing_normal}, $uri];
                $got_word = 1;
            }
            # ssh:// (and foo+ssh://) URIs
            elsif ($chunk =~ s{ ^ (?<uri> (?:\w+\+) ssh:// \S+ ) }{}xo) {
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
            elsif ($chunk =~ / ^ $WORD /xo) {
                # there's probably a simpler way to accomplish this
                my @words;
                while (1) {
                    last if $chunk !~ s/^($WORD)//o;
                    push @words, $1;
                }

                for my $word (@words) {
                    # Maybe preserve the casing of this word
                    $word = lc $word
                        if $word ne uc $word
                        # Mixed-case words like "WoW"
                        and $word !~ $MIXED_CASE
                        # Words that are upper case followed by a non-word character.
                        # {2,} so it doesn't match I'm
                        and $word !~ $UPPER_NONW;
                }

                if (@words == 1) {
                    push @tokens, [$self->{_spacing_normal}, $words[0]];
                }
                elsif (@words == 2) {
                    # When there are two words joined together, we need to
                    # decide if it's normal+postfix (e.g. "4.1GB") or
                    # prefix+normal (e.g. "v2.3")

                    if ($words[0] =~ /$NUMBER/ && $words[1] =~ /$ALPHA_WORD/) {
                        push @tokens, [$self->{_spacing_normal}, $words[0]];
                        push @tokens, [$self->{_spacing_postfix}, $words[1]];
                    }
                    elsif ($words[0] =~ /$ALPHA_WORD/ && $words[1] =~ /$NUMBER/) {
                        push @tokens, [$self->{_spacing_prefix}, $words[0]];
                        push @tokens, [$self->{_spacing_normal}, $words[1]];
                    }
                }
                else {
                    # When 3 or more words are together, (e.g. "800x600"),
                    # we treat them as two normal tokens surrounding one or
                    # more infix tokens
                    push @tokens, [$self->{_spacing_normal}, $_] for $words[0];
                    push @tokens, [$self->{_spacing_infix},  $_] for @words[1..$#words-1];
                    push @tokens, [$self->{_spacing_normal}, $_] for $words[-1];
                }

                $got_word = 1;
            }
            # everything else
            elsif ($chunk =~ s/ ^ (?<non_word> $NON_WORD ) //xo) {
                my $non_word = $+{non_word};
                my $spacing = $self->{_spacing_normal};

                # was the previous token a word?
                if ($got_word) {
                    $spacing = length $chunk
                        ? $self->{_spacing_infix}
                        : $self->{_spacing_postfix};
                }
                # do we still have more tokens in this chunk?
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
