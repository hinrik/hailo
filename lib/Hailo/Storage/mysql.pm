package Hailo::Storage::mysql;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

our $VERSION = '0.08';

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
    CREATE DATABASE hailo;
    GRANT USAGE ON *.* TO hailo@localhost IDENTIFIED BY 'hailo';
    GRANT ALL ON hailo.* TO hailo@localhost IDENTIFIED BY 'hailo';
    FLUSH PRIVILEGES;

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ query_exists_db ]__
SHOW TABLES;
