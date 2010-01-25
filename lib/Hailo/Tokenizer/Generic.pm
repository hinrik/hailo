package Hailo::Tokenizer::Generic;
use Moose;
use List::MoreUtils qw<uniq>;

our $VERSION = '0.01';

with 'Hailo::Tokenizer';

my $APOSTROPHE  = qr/['’]/;
my $WORD        = qr/\w+(?:$APOSTROPHE\w+)*/;
my $TOKEN       = qr/(?:$WORD| +|.)/s;
my $OPEN_QUOTE  = qr/['"‘“«»„「『‹]/;
my $TERMINATOR  = qr/(?:[…?!.‽]|$WORD:)/;
my $INTERESTING = qr/[[:alpha:]]/;

# output -> tokens
sub make_tokens {
    my ($self, $line) = @_;
    my (@tokens) = $line =~ /($TOKEN)/gs;

    # lower-case everything except those which are ALL UPPERCASE
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
    $string =~ s/(?:^\n|\n$)//gs;

    # capitalize the first letter of every sentence
    $string =~ s/^($OPEN_QUOTE?)($WORD)/$1.ucfirst($2)/e;
    $string =~ s/($WORD)($TERMINATOR\s+)($OPEN_QUOTE?)($WORD)/$1.$2.$3.ucfirst($4)/eg;

    # capitalize the word 'I' between word boundaries
    # except after an apostrophe
    $string =~ s{(?<!$APOSTROPHE)\bi\b}{I}g;

    return $string;
}

__PACKAGE__->meta->make_immutable;

1;

=encoding utf8

=head1 NAME

Hailo::Tokenizer::Perl - A generic tokenizer for L<Hailo|Hailo>

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
