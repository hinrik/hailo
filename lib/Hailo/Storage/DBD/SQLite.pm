package Hailo::Storage::DBD::SQLite;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use Hailo::Storage::DBD::SQLite::Tokenizer;
use DBI qw(:sql_types);
use namespace::clean -except => 'meta';

our $VERSION = '0.14';

extends 'Hailo::Storage::Mixin::DBD';

has '+dbd' => (
    default => 'SQLite',
);

override _build_dbd_options => sub {
    return {
        %{ super() },
        sqlite_unicode => 1,
    };
};

before _engage => sub {
    my ($self) = @_;
    my $size = $self->arguments->{cache_size};
    $self->dbh->do("PRAGMA cache_size=$size;") if defined $size;
    # OMGWTFBUBBLEGUM
    $self->inject_tokenizer();
    return;
};

before start_training => sub {
    my $dbh = shift->dbh;
    $dbh->do('PRAGMA synchronous=OFF;');
    $dbh->do('PRAGMA journal_mode=OFF;');
    return;
};

after stop_training => sub {
    my $dbh = shift->dbh;
    $dbh->do('PRAGMA journal_mode=DELETE;');
    $dbh->do('PRAGMA synchronous=ON;');
    return;
};

sub _exists_db {
    my ($self) = @_;
    my $brain = $self->brain;
    return unless defined $self->brain;
    return if $self->brain eq ':memory:';
    return -s $self->brain;
}

sub inject_tokenizer {
    my ($self) = @_;
    my $ptr = Hailo::Storage::DBD::SQLite::Tokenizer::get_tokenizer_ptr();

    # HACK. Doing this because using '?' and $sth->bind_param(2, $ptr,
    # SQL_BLOB); ends up passing nothing to
    # sqlite. I.e. sqlite3_value_bytes(argv[1]); will be 0
    my $pptr = pack "P", $ptr;

    my $sth = $self->dbh->prepare("SELECT fts3_tokenizer(?, '$pptr')");
    $sth->bind_param(1, "Hailo_tokenizer");

    $sth->execute();
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::DBD::SQLite - A storage backend for L<Hailo|Hailo> using
L<DBD::SQLite|DBD::SQLite>

=head1 SYNOPSIS

As a module:

my $hailo = Hailo->new(
     train_file    => 'hailo.trn',
     storage_class => 'SQLite',
     storage_args  => {
         cache_size > 102400, # 100MB page cache
     },
 );

From the command line:

 hailo --train hailo.trn --storage SQLite --storage-args cache_size=102400

See L<Hailo's documentation|Hailo> for other non-MySQL specific options.

=head1 DESCRIPTION

This backend maintains information in an SQLite database. It is the default
storage backend.

For some example numbers, I have a 2nd-order database built from a ~210k line
(7.4MB) IRC channel log file. With the default L<cache_size/storage_args>,
it took my laptop (Core 2 Duo 2.53 GHz, Intel X25-M hard drive) 5 minutes and
40 seconds (~617 lines/sec) to create the 98MB database. Furthermore, it
could generate about 33 replies per second from it.

=head1 ATTRIBUTES

=head2 C<storage_args>

This is a hash reference which can have the following keys:

B<'cache_size'>, the size of the page cache used by SQLite. See L<SQLite's
documentation|http://www.sqlite.org/pragma.html#pragma_cache_size> for more
information. Setting this value higher than the default can be beneficial,
especially when disk IO is slow on your machine.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason and
Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ query_last_expr_rowid ]__
SELECT last_insert_rowid();
__[ query_last_token_rowid ]__
SELECT last_insert_rowid();
