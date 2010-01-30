package Hailo::Storage::Pg;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;

our $VERSION = '0.01';

extends 'Hailo::Storage::SQL';

has '+dbd' => (
    default => 'Pg',
);

has '+dbd_options' => (
    default => sub { +{
        pg_enable_utf8 => 1,
        RaiseError => 1,
    } },
);

sub _build_dbi_options {
    my ($self) = @_;
    my $dbd = $self->dbd;
    my $dbd_options = $self->dbd_options;
    my $args = $self->arguments;

    my $conn_line = "dbi:$dbd";
    $conn_line .= ":dbname=$args->{dbname}"  if exists $args->{dbname};
    $conn_line .= ";host=$args->{host}"    if exists $args->{host};
    $conn_line .= ";port=$args->{port}"    if exists $args->{port};
    $conn_line .= ";options=$args->{options}" if exists $args->{options};

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
    return int $self->sth->{exists_db}->fetchrow_array;
}

# These two are optimized to use PostgreSQL >8.2's INSERT ... RETURNING 
sub _add_expr {
    my ($self, $token_ids, $can_start, $can_end, $expr_text) = @_;

    # add the expression
    $self->sth->{add_expr}->execute(@$token_ids, $can_start, $can_end, $expr_text);

    # get the new expr id
    return $self->sth->{add_expr}->fetchrow_array;
}

sub _add_token {
    my ($self, $token) = @_;

    $self->sth->{add_token}->execute($token);
    return $self->sth->{add_token}->fetchrow_array;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Pg - A storage backend for L<Hailo|Hailo> using
L<DBD::Pg|DBD::Pg>

=head1 SYNOPSIS

As a module:

    my $hailo = Hailo->new(
        train_file    => 'hailo.trn',
        storage_class => 'Pg',
        storage_args  => {
            dbname    => 'hailo',
            host      => 'localhost',
            port      => '5432',
            options   => '...',
            username  => 'hailo',
            password  => 'hailo'
        },
    );

From the command line:

    hailo --train        hailo.trn \
          --storage      Pg \
          --storage-args dbname=hailo \
          --storage-args host=localhost \
          --storage-args port=5432 \
          --storage-args options=... \
          --storage-args username=hailo \
          --storage-args password=hailo

Almost all of these options can be omitted, see L<DBD::Pg's
documentation|DBD::Pg/"connect"> for the default values.

See L<Hailo's documentation|Hailo> for other non-Pg specific options.

=head1 DESCRIPTION

This backend maintains information in a PostgreSQL database.

=head1 CAVEATS

It's around 8x-10x slower than L<the SQLite
backend|Hailo::Storage::SQLite> in my tests. Maybe this is due to an
unoptimal PostgreSQL configuration (I used the Debian defaults) or
perhaps the schema we're using simply suits SQLite better.

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
    can_start BOOL,
    can_end   BOOL,
[% FOREACH i IN orders %]
    token[% i %]_id INTEGER NOT NULL REFERENCES token (token_id),
[% END %]
    expr_text TEXT NOT NULL UNIQUE
);
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
__[ query_add_token ]__
INSERT INTO token (text) VALUES (?) RETURNING token_id;
__[ query_(add_expr) ]__
INSERT INTO expr ([% columns %], can_start, can_end, expr_text) VALUES ([% ids %], ?, ?, ?) RETURNING expr_id;
__[ query_exists_db ]__
SELECT count(*) FROM information_schema.columns WHERE table_name ='info';
