package Hailo::UI::ReadLine;
use 5.010;
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use Encode 'decode';
use Hailo;
use Term::ReadLine;
use namespace::clean -except => 'meta';

with qw(Hailo::Role::Arguments
        Hailo::Role::UI);

sub BUILD {
    $ENV{PERL_RL} = 'Perl o=0' unless $ENV{PERL_RL};
    return;
}

sub run {
    my ($self, $hailo) = @_;
    my $name = 'Hailo';
    my $term = Term::ReadLine->new($name);

    while (defined (my $line = $term->readline($name . '> '))) {
        $line = decode('utf8', $line);
        my $answer = $hailo->learn_reply($line);
        say $answer // "I don't know enough to answer you yet.";
    }
    print "\n";

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
