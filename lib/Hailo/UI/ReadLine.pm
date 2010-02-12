package Hailo::UI::ReadLine;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use Hailo;
use Term::ReadLine;
use namespace::clean -except => 'meta';

our $VERSION = '0.11';

with qw(Hailo::Role::Generic
        Hailo::Role::UI);

# Use Gnu readline
sub BUILD {
    my ($self) = @_;
    require Term::ReadLine::Gnu;
    $ENV{PERL_RL} = 'Gnu';
    return;
}

sub run {
    my ($self, $hailo) = @_;
    my $name = ref $hailo;
    my $term = Term::ReadLine->new($name);

    while (defined (my $line = $term->readline(lc($name) . '> '))) {
        if ($line =~ /^\s*$/s) {
            say "Provide some input to $name";
        } else {
            my $answer = $hailo->reply($line);
            say $answer // "I don't know enough to answer you yet.";
        }
    }

    return;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::UI::ReadLine - A UI for L<Hailo|Hailo> using L<Term::ReadLine|Term::ReadLine>

=head1 SYNOPSIS

This module is called internally by L<Hailo|Hailo>, it takes no options.

A ReadLine interface will be presented when calling L<hailo> on the
command-line with only a C<--brain> argument:

    hailo --brain a-brain.brn

=head1 DESCRIPTION

Presents a ReadLine interface using L<Term::ReadLine>, the
L<Term::ReadLine::Gnu> frontend will be used.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
