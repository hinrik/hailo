package Hailo::Tokenizer::Words;

use 5.010;
use utf8;
use Any::Moose;
use Any::Moose 'X::StrictConstructor';
use Regexp::Common qw/ URI /;
use namespace::clean -except => 'meta';

with qw(Hailo::Role::Arguments
        Hailo::Role::Tokenizer);

# [[:alpha:]] doesn't match combining characters on Perl >=5.12
my $ALPHABET   = qr/(?![_\d])\w/;

# tokenization
my $SPACE      = qr/[\n ]/;
my $NONSPACE   = qr/[^\n ]/;
my $DASH       = qr/[–-]/;
my $POINT      = qr/[.,]/;
my $APOSTROPHE = qr/['’´]/;
my $ELLIPSIS   = qr/\.{2,}|…/;
my $NON_WORD   = qr/[^\w\n ]+/;
my $BARE_WORD  = qr/\w+/;
my $NUMBER     = qr/$POINT\d+(?:$POINT\d+)*|\d+(?:$POINT\d+)+$ALPHABET*/;
my $APOST_WORD = qr/$ALPHABET+(?:$APOSTROPHE$ALPHABET+)+/;
my $ABBREV     = qr/$ALPHABET(?:\.$ALPHABET)+\./;
my $DOTTED     = qr/$BARE_WORD?\.$BARE_WORD(?:\.$BARE_WORD)*/;
my $WORD_TYPES = qr/$NUMBER|$ABBREV|$DOTTED|$APOST_WORD|$BARE_WORD/;
my $WORD_APOST = qr/$WORD_TYPES(?:$DASH$WORD_TYPES)*$APOSTROPHE(?!$ALPHABET|$NUMBER)/;
my $WORD       = qr/$WORD_TYPES(?:(?:$DASH$WORD_TYPES)+|$DASH(?!$DASH))?/;
my $MIXED_CASE = qr/ \p{Lower}+ \p{Upper} /x;
my $UPPER_NONW = qr/^ (?:\p{Upper}+ \W+)(?<!I') (?: \p{Upper}* \p{Lower} ) /x;

# special tokens
my $TWAT_NAME  = qr/ \@ [A-Za-z0-9_]+ /x;
my $EMAIL      = qr/ [A-Z0-9._%+-]+ @ [A-Z0-9.-]+ \. [A-Z]{2,4} /xi;
my $PERL_CLASS = qr/ (?: :: \w+ (?: :: \w+ )* | \w+ (?: :: \w+ )+ ) (?: :: )? | \w+ :: /x;
my $EXTRA_URI  = qr{ (?: \w+ \+ ) ssh:// $NONSPACE+ }x;
my $ESC_SPACE  = qr/(?:\\ )+/;
my $NAME       = qr/(?:$BARE_WORD|$ESC_SPACE)+/;
my $FILENAME   = qr/ $NAME? \. $NAME (?: \. $NAME )* | $NAME/x;
my $UNIX_PATH  = qr{ / $FILENAME (?: / $FILENAME )* /? }x;
my $WIN_PATH   = qr{ $ALPHABET : \\ $FILENAME (?: \\ $FILENAME )* \\?}x;
my $PATH       = qr/$UNIX_PATH|$WIN_PATH/;
my $DATE       = qr/[0-9]{4}-W?[0-9]{1,2}-[0-9]{1,2}/i;
my $TIME       = qr/[0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:Z|[AP]M|[-+±][0-9]{2}(?::?[0-9]{2})?)?/i;
my $DATETIME   = qr/${DATE}T$TIME/;
my $IRC_NICK   = qr/<[ @%+~&]?[A-Za-z_`\-^\|\\\{}\[\]][A-Za-z_0-9`\-^\|\\\{}\[\]]+>/;

my $CASED_WORD = qr/$IRC_NICK|$DATETIME|$DATE|$TIME|$PERL_CLASS|$EXTRA_URI|$EMAIL|$TWAT_NAME|$PATH/;

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
my $LOOSE_WORD  = qr/$DATETIME|$DATE|$TIME|$PATH|$NUMBER|$ABBREV|$APOST_WORD|$BARE_WORD(?:$DASH(?:$WORD_TYPES|$BARE_WORD)|$APOSTROPHE(?!$ALPHABET|$NUMBER|$APOSTROPHE)|$DASH(?!$DASH{2}))*/;
my $SPLIT_WORD  = qr{$LOOSE_WORD(?:/$LOOSE_WORD)?(?=$PUNCTUATION(?:\s+|$)|$CLOSE_QUOTE|$TERMINATOR|\s+|$)};

# we want to capitalize words that come after "On example.com?"
# or "You mean 3.2?", but not "Yes, e.g."
my $DOTTED_STRICT = qr/$LOOSE_WORD(?:$POINT(?:\d+|\w{2,}))?/;
my $WORD_STRICT   = qr/$DOTTED_STRICT(?:$APOSTROPHE$DOTTED_STRICT)*/;

# input -> tokens
sub make_tokens {
    my ($self, $input) = @_;

    my @tokens;
    $input =~ s/$DASH\K *\n+ *//;
    $input =~ s/ *\n+ */ /gm;

    while (length $input) {
        # remove the next chunk of whitespace
        $input =~ s/^[\n ]+//;
        my $got_word;

        while (length $input && $input =~ /^$NONSPACE/) {
            # We convert it to ASCII and then look for a URI because $RE{URI}
            # from Regexp::Common doesn't support non-ASCII domain names
            my ($ascii) = $input =~ /^($NONSPACE+)/;
            $ascii =~ s/[^[:ascii:]]/a/g;

            # URIs
            if (!$got_word && $ascii =~ / ^ $RE{URI} /xo) {
                my $uri_end = $+[0];
                my $uri = substr $input, 0, $uri_end;
                $input =~ s/^\Q$uri//;

                push @tokens, [$self->{_spacing_normal}, $uri];
                $got_word = 1;
            }
            # special words for which we preserve case
            elsif (!$got_word && $input =~ s/ ^ (?<word> $CASED_WORD )//xo) {
                push @tokens, [$self->{_spacing_normal}, $+{word}];
                $got_word = 1;
            }
            # normal words
            elsif ($input =~ / ^ $WORD /xo) {
                my $word;

                # special case to allow matching q{ridin'} as one word, even when
                # it appears as q{"ridin'"}, but not as q{'ridin'}
                my $last_char = @tokens ? substr $tokens[-1][1], -1, 1 : '';
                if (!@tokens && $input =~ s/ ^ (?<word>$WORD_APOST) //xo
                    || $last_char =~ / ^ $APOSTROPHE $ /xo
                    && $input =~ s/ ^ (?<word>$WORD_APOST) (?<! $last_char ) //xo) {
                    $word = $+{word};
                }
                else {
                    $input =~ s/^($WORD)//o and $word = $1;
                }

                # Maybe preserve the casing of this word
                $word = lc $word
                    if $word ne uc $word
                    # Mixed-case words like "WoW"
                    and $word !~ $MIXED_CASE
                    # Words that are upper case followed by a non-word character.
                    and $word !~ $UPPER_NONW;

                push @tokens, [$self->{_spacing_normal}, $word];
                $got_word = 1;
            }
            # everything else
            elsif ($input =~ s/ ^ (?<non_word> $NON_WORD ) //xo) {
                my $non_word = $+{non_word};
                my $spacing = $self->{_spacing_normal};

                # was the previous token a word?
                if ($got_word) {
                    $spacing = $input =~ /^$NONSPACE/
                        ? $self->{_spacing_infix}
                        : $self->{_spacing_postfix};
                }
                # do we still have more tokens?
                elsif ($input =~ /^$NONSPACE/) {
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
    $reply =~ s/^\s*$OPEN_QUOTE?\s*\K($SPLIT_WORD)(?=$ELLIPSIS|(?:(?:$CLOSE_QUOTE|$TERMINATOR|$ADDRESS|$PUNCTUATION+)?(?:\s|$)))/\u$1/o;

    # capitalize the second word
    $reply =~ s/^\s*$OPEN_QUOTE?\s*$SPLIT_WORD(?:(?:\s*$TERMINATOR|$ADDRESS)\s+)\K($SPLIT_WORD)/\u$1/o;

    # capitalize all other words after word boundaries
    # we do it in two passes because we need to match two words at a time
    $reply =~ s/(?:$ELLIPSIS|\s+)$OPEN_QUOTE?\s*$WORD_STRICT$BOUNDARY\K($SPLIT_WORD)/\x1B\u$1\x1B/go;
    $reply =~ s/\x1B$WORD_STRICT\x1B$BOUNDARY\K($SPLIT_WORD)/\u$1/go;
    $reply =~ s/\x1B//go;

    # end paragraphs with a period when it makes sense
    $reply =~ s/(?:$ELLIPSIS|\s+|^)$OPEN_QUOTE?(?:$SPLIT_WORD(?:\.$SPLIT_WORD)*)\K($CLOSE_QUOTE?)$/.$1/o;

    # capitalize I'm, I've...
    $reply =~ s{(?:(?:$ELLIPSIS|\s+)|$OPEN_QUOTE)\Ki(?=$APOSTROPHE$ALPHABET)}{I}go;

    return $reply;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Tokenizer::Words - A tokenizer for L<Hailo|Hailo> which splits
on whitespace and word boundaries, mostly.

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
