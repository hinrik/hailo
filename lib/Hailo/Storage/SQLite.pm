package Hailo::Storage::SQLite;

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

sub _build_dbd { return 'SQLite' };

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
            and $self->arguments->{in_memory});
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

    my %pragmas;

    # speedy defaults when DB is not kept in memory
    if (!$self->{in_memory}) {
        $pragmas{synchronous}  = 'OFF';
        $pragmas{journal_mode} = 'OFF';
    }

    while (my ($k, $v) = each %{ $self->arguments }) {
        if (my ($pragma) = $k =~ /^pragma_(.*)/) {
            $pragmas{$pragma} = $v;
        }
    }

    while (my ($k, $v) = each %pragmas) {
        $self->dbh->do(qq[PRAGMA $k="$v";])
    }

    return;
}

sub save {
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

Hailo::Storage::SQLite - A storage backend for L<Hailo|Hailo> using L<DBD::SQLite>

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

=head3 C<pragma_*>

Any option starting with B<'pragma_'> will be considered to be an L<SQLite
pragma|http://www.sqlite.org/pragma.html> which will be set after we connect
to the database. An example of this would be

    storage_args => {
        pragma_cache_size  => 10000,
        pragma_synchronous => 'OFF',
    }

Setting B<'pragma_cache_size'> in particular can be beneficial. It's the
size of the page cache used by SQLite. See L<SQLite's
documentation|http://www.sqlite.org/pragma.html#pragma_cache_size> for
more information.

Increasing it might speed up Hailo, especially when disk IO is slow on
your machine. Obviously, you shouldn't bother with this option if
L<B<'in_memory'>|/in_memory> is enabled.

Setting B<'pragma_synchronous'> to B<'OFF'> or B<'pragma_journal_mode'>
to B<'OFF'> will speed up operations at the expense of safety. Since Hailo
is most likely not running as a mission-critical component this trade-off
should be acceptable in most cases. If the database becomes corrupt
it's easy to rebuild it by retraining from the input it was trained on
to begin with. For performance reasons, these two are set to B<'OFF'>
by default unless L<B<'in_memory'>|/in_memory> is enabled.

=head3 C<in_memory>

When set to a true value, Hailo behaves much like MegaHAL.  The entire
database will be kept in memory, and only written out to disk when the
L<C<save>|Hailo/save> method is called and/or when the Hailo object gets
destroyed (unless you disabled
L<C<save_on_exit>|Hailo/save_on_exit>). This is disabled by default.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason and
Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
