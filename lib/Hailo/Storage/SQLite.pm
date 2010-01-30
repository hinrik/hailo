package Hailo::Storage::SQLite;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;

our $VERSION = '0.01';

extends 'Hailo::Storage::SQL';

has '+dbd' => (
    default => 'SQLite',
);

has '+dbd_options' => (
    default => sub { +{
        sqlite_unicode => 1,
        RaiseError => 1,
    } },
);

before start_training => sub {
    shift->dbh->do('PRAGMA synchronous=OFF;');
    return;
};

after stop_training => sub {
    shift->dbh->do('PRAGMA synchronous=ON;');
    return;
};

sub _exists_db {
    my ($self) = @_;
    my $brain = $self->brain;
    return unless defined $self->brain;
    return -s $self->brain;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::SQLite - A storage backend for L<Hailo|Hailo> using
L<DBD::SQLite|DBD::SQLite>

=head1 DESCRIPTION

This backend maintains information in an SQLite database. It can handle
pretty large datasets.

For some example numbers, I have a 5th-order database built from a 204k line
(7.2MB) IRC channel log file (7.2MB). On my laptop (Core 2 Duo 2.53 GHz) it
took 10 minutes and 42 seconds (317 lines/sec) to create the 290MB database.
Furthermore, it can generate 166 replies per second from it. Since this is
just an SQL database, there is very little RAM usage.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ table_expr ]__
CREATE TABLE expr (
    expr_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    can_start BOOL,
    can_end   BOOL,
[% FOREACH i IN orders %]
    token[% i %]_id INTEGER NOT NULL REFERENCES token (token_id),
[% END %]
    expr_text TEXT NOT NULL UNIQUE
);
__[ query_last_expr_rowid ]_
SELECT last_insert_rowid();
__[ query_last_token_rowid ]__
SELECT last_insert_rowid();
