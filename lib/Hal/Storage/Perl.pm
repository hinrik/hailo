package Hal::Storage::Perl;

use strict;
use warnings;
use Storable;

use base 'Hal::Storage';
our $VERSION = '0.01';

sub order {
    my ($self) = @_;
    return $self->{memory}{order};
}

sub new {
    my ($package, %args) = @_;
    my $self = bless \%args, $package;
    my $order = delete $self->{order};
    
    if (defined $self->{file} && -s $self->{file}) {
        $self->_load($self->{file});
    }
    else {
        $self->{memory} = {
            tokens      => { }, # $token => \%blurbs_that_contain_it
            blurbs      => { }, # $bhash => \%blurb
            next_tokens => { }, # $bhash => \%tokens_that_can_follow_this_blurb
            prev_tokens => { }, # $bhash => \%tokens_that_can_precede_this_blurb
            order       => $order,
        };
    }

    return $self;
}

sub add_blurb {
    my ($self, %args) = @_;
    my $mem = $self->{memory};

    my $bhash = _hash_tokens($args{blurb}{tokens});
    $mem->{blurbs}{$bhash} = $args{blurb};

    for my $token (@{ $args{blurb}{tokens} }) {
        $mem->{tokens}{$token}{$bhash} = 1 if !exists $mem->{tokens}{$token}{$bhash};
    }

    if (defined $args{next_token}) {
        if (!exists $mem->{next_tokens}{$bhash}{$args{next_token}}) {
            $mem->{next_tokens}{$bhash}{$args{next_token}} = 1;
        }
    }

    if (defined $args{prev_token}) {
        if (!exists $mem->{prev_tokens}{$bhash}{$args{prev_token}}) {
            $mem->{prev_tokens}{$bhash}{$args{prev_token}} = 1;
        }
    }
    
    return;
}

sub token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->{memory}{tokens}{$token};
    return;
}

sub find_blurb {
    my ($self, @tokens) = @_;
    my $bhash = _hash_tokens(\@tokens);
    return $self->{memory}{blurbs}{$bhash};
}

sub random_blurb {
    my ($self, $token) = @_;
    my @bhash = keys %{ $self->{memory}{tokens}{$token} };
    return $self->{memory}{blurbs}{ $bhash[rand @bhash] };
}

sub next_tokens {
    my ($self, $blurb) = @_;
    my $bhash = _hash_tokens($blurb->{tokens});
    return $self->{memory}{next_tokens}{ $bhash };
}

sub prev_tokens {
    my ($self, $blurb) = @_;
    my $bhash = _hash_tokens($blurb->{tokens});
    return $self->{memory}{prev_tokens}{ $bhash };
}

# hash the contents of a blurb for unique identification
# pretty naïve so far, just joins all the tokens with a newline,
# since newlines aren't allowed
sub _hash_tokens {
    my ($tokens) = @_;
    my $bhash = join "\n", @$tokens;
    return $bhash;
}

sub _load {
    my ($self, $file) = @_;
    $self->{memory} = retrieve($self->{file});
    return;
}

sub save {
    my ($self) = @_;
    store($self->{memory}, $self->{file});
    return;
}

1;

=encoding utf8

=head1 NAME

Hal::Storage::Perl - A storage backend for L<Hal|Hal> using Perl structures

=head1 DESCRIPTION

This backend maintains information in a Perl hash, with an option to
save to/load from a file with L<Storable|Storable>.

It is fast, but uses a lot of memory.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
