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
use Data::Dump 'dump';
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
    my $command = qr[
        ^
        # A dot-prefix like in SQLite
        \.
        # We only have Hailo methods matching this
        (?<method> [a-z_]+ )
        # Optional arguments. These'll be passed to eval() before being
        # passed to the method
        \s*
        (?: (?<arguments>.+) )?
    $]x;

    print $self->_intro;

    while (defined (my $line = $term->readline($name . '> '))) {
        $line = decode('utf8', $line);

        given ($line) {
            when (/$command/p) {
                when ($+{method} eq 'help') {
                    print $self->_help($hailo);
                }
                when ($+{method} ~~ [ qw< quit exit >]) {
                    say $hailo->reply("Dave, this conversation can serve no purpose anymore. Goodbye.") // "Bye!";
                    exit 0;
                }
                default {
                    my $meth = $+{method};
                    my @args = defined $+{arguments} ? eval $+{arguments} : ();

                    local ($@, $!);
                    eval {
                        say dump $hailo->$meth(@args);
                    };
                    if (my $err = $@) {
                        chomp $err;
                        say STDERR "Failed on <<${^MATCH}>>: <<$err>>";
                    }
                }
            }
            default {
                my $answer = $hailo->learn_reply($line);
                say $answer // "I don't know enough to answer you yet.";
            }
        }
    }
    print "\n";

    return;
}

sub _intro {
    my ($self) = @_;
    my $intro = <<"INTRO";
Welcome to the Hailo interactive shell
Enter ".help" to show the built-in commands.
Input that's not a command will be passed to Hailo to learn, and it'll
reply back.
INTRO
    return $intro;
}

sub _help {
    my ($self, $hailo) = @_;

    my $include = qr/ ^ _go /x;
    my $exclude = qr/
        _
       (?:
           version
         | order
         | progress
         | random_reply
         | examples
         | autosave
         | brain
         | class
       )
    $/x;

    my @attr;
    for my $attr ($hailo->meta->get_all_attributes) {
        # Only get attributes that are valid command-line options
        next unless $attr->name ~~ $include;

        # We don't support changing these in mid-stream
        next if $attr->name ~~ $exclude;

        push @attr => {
            name => do {
                my $tmp = $attr->cmd_flag;
                $tmp =~ tr/-/_/;
                $tmp;
            },
            documentation => $attr->documentation,
        };
    }

    push @attr => {
        name => 'quit',
        documentation => "Exit this chat session",
    };

    my $help = <<"HELP";
These are the commands we know about:

HELP

    my @sorted = sort { $a->{name} cmp $b->{name} } @attr;
    for my $cmd (@sorted) {
        $help .= sprintf "    %-14s%s\n", '.'.$cmd->{name}, $cmd->{documentation};
    }

    $help .= <<"HELP";

The commands are just method calls on a Hailo object. Any arguments to
them will be passed through eval() used as method arguments. E.g.:

    .train "/tmp/megahal.trn"
    Trained from 350 lines in 0.54 seconds; 654.04 lines/s
    ()

Return values are printed with Data::Dump:

    .stats
    (1311, 2997, 3580, 3563)

Any input not starting with "." will be passed through Hailo's
learn_reply method:

    Hailo> Help, mommy!
    Really? I can't. It's an ethical thing.

HELP

    return $help;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::UI::ReadLine - A UI for L<Hailo|Hailo> using L<Term::ReadLine|Term::ReadLine>

=head1 SYNOPSIS

This module is called internally by L<Hailo|Hailo>, it takes no options.

A ReadLine interface will be presented when calling L<hailo> on the
command-line with only a C<--brain> argument:

    hailo --brain hailo.sqlite

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
