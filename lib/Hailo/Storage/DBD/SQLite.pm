package Hailo::Storage::DBD::SQLite;
use 5.010;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

our $VERSION = '0.17';

extends 'Hailo::Storage::DBD';

override _build_dbd         => sub { 'SQLite' };
override _build_dbd_options => sub {
    return {
        %{ super() },
        sqlite_unicode => 1,
    };
};

around _build_dbi_options => sub {
    my $orig = shift;
    my $self = shift;

    my $return;
    if ($self->_backup_memory_to_disk) {
        my $file = $self->brain;
        $self->brain(':memory:');
        $return = $self->$orig(@_);
        $self->brain($file);
    }
    else {
        $return = $self->$orig(@_);
    }

    return $return;
};

# Are we running in a mixed mode where we run in memory but
# restore/backup to disk?
sub _backup_memory_to_disk {
    my ($self) = @_;

    return (defined $self->brain
            and $self->brain ne ':memory:'
            and (not defined $self->arguments->{in_memory}
            or $self->arguments->{in_memory}));
}


before _engage => sub {
    my ($self) = @_;

    # Set any user-defined pragmas
    $self->_set_pragmas;

    if ($self->_exists_db and $self->_backup_memory_to_disk) {
        $self->dbh->sqlite_backup_from_file($self->brain);
    }

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

sub ready {
    my ($self) = @_;
    my $brain = $self->brain;
    return unless defined $self->brain;
    return 1 if $self->brain eq ':memory:';
    return 1;
}

sub _set_pragmas {
    my ($self) = @_;

    return unless exists $self->arguments->{pragmas};
    my $pragmas = $self->arguments->{pragmas};
    die "Pragmas must be a HashRef" unless ref $pragmas eq 'HASH';

    while (my ($k, $v) = each %$pragmas) {
        $self->dbh->do(qq[PRAGMA $k="$v";])
    }

    return;
}

override save => sub {
    my ($self, $filename) = @_;
    my $file = $filename // $self->brain;

    return unless $self->_engaged;
    if ($self->_backup_memory_to_disk) {
        $self->dbh->sqlite_backup_to_file($file);
    }
    return;
};

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
 );

From the command line:

 hailo --train hailo.trn --storage SQLite

See L<Hailo's documentation|Hailo> for other non-MySQL specific options.

=head1 DESCRIPTION

This backend maintains information in an SQLite database. It is the default
storage backend.

=head1 ATTRIBUTES

=head2 C<storage_args>

This is a hash reference which can have the following keys:

=head3 C<in_memory>

When set to a true value, Hailo behaves much like MegaHAL.  The entire
database will be kept in memory, and only written out to disk when the
C<save|Hailo/save> method is called and/or when the L<Hailo|Hailo>
object gets destroyed (unless you disabled
L<save_on_exit|Hailo/save_on_exit>). This is turned on by default, to
disable it set C<in_memory => 0>.

=head3 C<pragmas>

A hash reference of L<SQLite
pragmas|http://www.sqlite.org/pragma.html> that will be set when the
database connection is set up, an example of this would be:

    pragmas => {
        foreign_keys => 1,
        synchronous => 0,
    };

Setting B<'cache_size'> in particular can be benificial, it's the size
of the page cache used by SQLite. See L<SQLite's
documentation|http://www.sqlite.org/pragma.html#pragma_cache_size> for
more information.

Setting it will speed up Hailo, especially when disk IO is slow on
your machine. Obviously, you shouldn't bother with this option if
B<'in_memory'> is enabled.

Setting B<'synchronous'> to B<'OFF'> or B<'journal_mode'> to B<'OFF'>
will speed up operations at the expense of safety. Since Hailo is most
likely not running as a mission-critical component this tradeoff
should be acceptable in most cases, if the database becomes corrupt
it's easy to rebuild it by retraining from the input it was trained on
to begin with.

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
__[ static_query_last_expr_rowid ]__
SELECT last_insert_rowid();
__[ static_query_last_token_rowid ]__
SELECT last_insert_rowid();
__[ static_query_token_total ]__
SELECT seq FROM sqlite_sequence WHERE name = 'token';
__[ static_query_expr_total ]__
SELECT seq FROM sqlite_sequence WHERE name = 'expr';
__[ static_query_prev_total ]__
SELECT seq FROM sqlite_sequence WHERE name = 'prev_token';
__[ static_query_next_total ]__
SELECT seq FROM sqlite_sequence WHERE name = 'next_token';
