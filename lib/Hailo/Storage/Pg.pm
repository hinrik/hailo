package Hailo::Storage::Pg;
use 5.10.0;
use Moose;

extends 'Hailo::Storage::SQL';

our $VERSION = '0.01';

sub _build__dbh {
    my ($self) = @_;

    return DBI->connect(
        "dbi:Pg:dbname=".$self->file,
        '',
        '', 
        {
            pg_enable_utf8 => 1,
            RaiseError => 1,
        },
    );
}

sub _exists_db {
    my ($self) = @_;

    return shift->_dbh->selectrow_array("SELECT count(*) FROM information_schema.columns WHERE table_name ='info'") != 0;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Pg - A storage backend for L<Hailo|Hailo> using
L<DBD::Pg|DBD::Pg>

=head1 DESCRIPTION

This backend maintains information in a PostgreSQL database, the same
caveats apply to it as
L<Hailo::Storage::SQLite|Hailo::Storage::SQLite>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ table_token ]__
CREATE TABLE token (
    token_id SERIAL UNIQUE,
    text     TEXT NOT NULL
);
__[ table_expr ]__
CREATE TABLE expr (
    expr_id   SERIAL UNIQUE,
    expr_text TEXT NOT NULL UNIQUE
);
[% FOREACH i IN orders %]
ALTER TABLE expr ADD token[% i %]_id INTEGER REFERENCES token (token_id);
[% END %]
__[ table_next_token ]__
CREATE TABLE next_token (
    pos_token_id SERIAL UNIQUE,
    expr_id      INTEGER NOT NULL REFERENCES  expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ table_prev_token ]__
CREATE TABLE prev_token (
    pos_token_id SERIAL UNIQUE,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ query_last_expr_rowid ]_
SELECT expr_id  FROM expr  ORDER BY expr_id  DESC LIMIT 1;
__[ query_last_token_rowid ]__
SELECT token_id FROM token ORDER BY token_id DESC LIMIT 1;
