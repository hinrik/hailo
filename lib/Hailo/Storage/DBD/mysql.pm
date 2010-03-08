package Hailo::Storage::DBD::mysql;
use 5.010;
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use List::MoreUtils qw< all >;
use namespace::clean -except => 'meta';

extends 'Hailo::Storage::DBD';

override _build_dbd         => sub { 'mysql' };
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

sub ready {
    my ($self) = @_;

    return all { exists $self->arguments->{$_} } qw(database username password);
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::DBD::mysql - A storage backend for L<Hailo|Hailo> using
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

 hailo --train hailo.trn \
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

=head1 ATTRIBUTES

=head2 C<storage_args>

This is a hash reference which can have the following keys:

B<'database'>, the name of the database to use (required).

B<'host'>, the host to connect to (required).

B<'port'>, the port to connect to (required).

B<'username'>, the username to use.

B<'password'>, the password to use.

=head1 CAVEATS

MySQL sucks.

=head1 MySQL setup

Before creating a database for Hailo you need to ensure that the
B<collation_connection>, B<collation_database> and B<collation_server>
for the new database will be equivalent, you can do this by adding
this to your C<[mysqld]> section in F<my.cnf>:

    skip-character-set-client-handshake
    collation_server=utf8_unicode_ci
    character_set_server=utf8

Now when you create the database you should get something like this:

    mysql> show variables like 'coll%';
    +----------------------+-----------------+
    | Variable_name        | Value           |
    +----------------------+-----------------+
    | collation_connection | utf8_unicode_ci |
    | collation_database   | utf8_unicode_ci |
    | collation_server     | utf8_unicode_ci |
    +----------------------+-----------------+

If you instead get this:

    +----------------------+-------------------+
    | Variable_name        | Value             |
    +----------------------+-------------------+
    | collation_connection | utf8_unicode_ci   |
    | collation_database   | latin1_swedish_ci |
    | collation_server     | utf8_unicode_ci   |
    +----------------------+-------------------+

Then Hailo will eventually die when you train it on an error similar
to this:

    DBD::mysql::st execute failed: Illegal mix of collations (latin1_swedish_ci,IMPLICIT)
    and (utf8_unicode_ci,COERCIBLE) for operation '=' at [...]

After taking care of that create a MySQL database for Hailo using
something like these commands:

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
__[ static_query_exists_db ]__
SHOW TABLES;
