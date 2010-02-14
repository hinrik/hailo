package Hailo::Storage::DBD::SQLite;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
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

For some example numbers, I have a 5th-order database built from a ~210k line
(7.4MB) IRC channel log file. On my laptop (Core 2 Duo 2.53 GHz) it took 8
minutes and 50 seconds (~400 lines/sec) to create the 229MB database.
Furthermore, it can generate about 90 replies per second from it.

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
