#!/usr/bin/env perl
use 5.010;
use strict;
use warnings;
use Hailo;
use Test::More tests => 3;

{
    package Fernando;
    use Any::Moose;

    extends 'Hailo';

    our @dead;

    sub DEMOLISH {
        my ($self) = @_;
        push @dead => int($self);
    }
}

my @dead;

is_deeply(\@Fernando::dead, \@dead, "No Fernandos demolished yet");

{
    my $f = Fernando->new;
    push @dead => int($f);
}
is_deeply(\@Fernando::dead, \@dead, "A simple Fernando was demolished");

{
    my $f = Fernando->new( brain => ":memory:" );
    $f->train(__FILE__);
    push @dead => int($f);
}
is_deeply(\@Fernando::dead, \@dead, "A trained Fernando was demolished");

