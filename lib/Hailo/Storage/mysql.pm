package Hailo::Storage::mysql;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;

our $VERSION = '0.01';

extends 'Hailo::Storage::SQL';

has '+dbd' => (
    default => 'mysql',
);

override _build_dbd_options => sub {
    return {
        %{ super() },
        mysql_enable_utf8 => 1,
    };
};

sub _build_dbi_options {
    my ($self) = @_;
    my $dbd = $self->dbd;
    my $dbd_options = $self->dbd_options;
    my $args = $self->arguments;

    my $conn_line = "dbi:$dbd";
    $conn_line .= ":database=$args->{database}"  if exists $args->{database};
    $conn_line .= ";host=$args->{host}"          if exists $args->{host};
    $conn_line .= ";port=$args->{port}"          if exists $args->{port};

    my @options = (
        $conn_line,
        ($args->{username} || ''),
        ($args->{password} || ''),
        $dbd_options,
    );

    return \@options;
}

sub _exists_db {
    my ($self) = @_;

    $self->sth->{exists_db}->execute();
    return defined $self->sth->{exists_db}->fetchrow_array;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::mysql - A storage backend for L<Hailo|Hailo> using
L<DBD::mysql|DBD::mysql>

=head1 SYNOPSIS

As a module:

    my $hailo = Hailo->new(
        train_file    => 'hailo.trn',
        storage_class => 'mysql',
        storage_args  => {
            database  => 'hailo',
            host      => 'localhost',
            port      => '3306',
            username  => 'hailo',
            password  => 'hailo'
        },
    );

From the command line:

    hailo --train        hailo.trn \
          --storage      mysql \
          --storage-args database=hailo \
          --storage-args host=localhost \
          --storage-args port=3306 \
          --storage-args username=hailo \
          --storage-args password=hailo

Almost all of these options can be omitted, see L<DBD::mysql's
documentation|DBD::mysql> for the default values.

See L<Hailo's documentation|Hailo> for other non-MySQL specific options.

=head1 DESCRIPTION

This backend maintains information in a MySQL database.

=head1 CAVEATS

MySQL sucks.

=head1 Setup notes

Here's how I create a MySQL database for Hailo:

    mysql -u root -p
    mysql> CREATE DATABASE hailo;
    mysql> GRANT USAGE ON *.* TO hailo@localhost IDENTIFIED BY 'hailo';
    mysql> GRANT ALL ON hailo.* TO hailo@localhost IDENTIFIED BY 'hailo';
    mysql> FLUSH PRIVILEGES;

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ table_info ]__
CREATE TABLE info (
    attribute TEXT NOT NULL,
    text      TEXT NOT NULL
);
__[ table_token ]__
CREATE TABLE token (
    token_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    text     TEXT NOT NULL
);
__[ table_expr ]__
CREATE TABLE expr (
    expr_id   INTEGER PRIMARY KEY AUTO_INCREMENT,
    can_start BOOL,
    can_end   BOOL,
[% FOREACH i IN orders %]
    token[% i %]_id INTEGER NOT NULL REFERENCES token (token_id),
[% END %]
    expr_text TEXT NOT NULL
);
__[ table_next_token ]__
CREATE TABLE next_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ table_prev_token ]__
CREATE TABLE prev_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ table_indexes ]__
[% FOREACH i IN orders %]
CREATE INDEX expr_token[% i %]_id on expr (token[% i %]_id);
[% END %]
CREATE INDEX next_token_expr_id ON next_token (expr_id);
CREATE INDEX prev_token_expr_id ON prev_token (expr_id);
__[ query_exists_db ]__
SHOW TABLES;
