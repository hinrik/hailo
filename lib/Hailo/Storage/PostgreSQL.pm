package Hailo::Storage::PostgreSQL;

use 5.010;
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use namespace::clean -except => 'meta';

extends 'Hailo::Storage';
with qw(Hailo::Role::Arguments Hailo::Role::Storage);

sub _build_dbd { return 'Pg' };

override _build_dbd_options => sub {
    return {
        %{ super() },
        pg_enable_utf8 => 1,
    };
};

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

sub ready {
    my ($self) = @_;

    return exists $self->arguments->{dbname};
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::PostgreSQL - A storage backend for L<Hailo|Hailo> using L<DBD::Pg>

=head1 SYNOPSIS

First create a PostgreSQL database for failo:

    # Run it as a dedicated hailo user
    createdb -E UTF8 -O hailo hailo

    # Just create database..
    createdb -E UTF8 hailo

As a module:

    my $hailo = Hailo->new(
        train_file    => 'hailo.trn',
        storage_class => 'Pg',
        storage_args => {
            dbname   => 'hailo',
        },
    );

Or with complex connection options:

    my $hailo = Hailo->new(
        train_file    => 'hailo.trn',
        storage_class => 'Pg',
        storage_args => {
            dbname   => 'hailo',
            host     => 'localhost',
            port     => '5432',
            options  => '...',
            username => 'hailo',
            password => 'hailo'
        },
    );

From the command line:

    hailo --train hailo.trn \
        --storage      Pg \
        --storage-args dbname=hailo

Or with complex connection options:

    hailo --train hailo.trn \
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

=head1 ATTRIBUTES

=head2 C<storage_args>

This is a hash reference which can have the following keys:

B<'dbname'>, the name of the database to use (required).

B<'host'>, the host to connect to (required).

B<'port'>, the port to connect to (required).

B<'options'>, additional options to pass to PostgreSQL.

B<'username'>, the username to use.

B<'password'>, the password to use.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
