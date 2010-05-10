package Hailo::Storage;

use 5.010;
use Any::Moose;
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use DBI;
use Hailo::Storage::Schema;

has dbd => (
    isa           => 'Str',
    is            => 'ro',
    lazy_build    => 1,
    documentation => "The DBD::* driver we're using",
);

has dbd_options => (
    isa           => 'HashRef',
    is            => 'ro',
    lazy_build    => 1,
    documentation => 'Options passed as the last argument to DBI->connect()',
);

sub _build_dbd_options {
    my ($self) = @_;
    return {
        RaiseError => 1
    };
}

has dbh => (
    isa           => 'DBI::db',
    is            => 'ro',
    lazy_build    => 1,
    documentation => 'Our DBD object',
);

sub _build_dbh {
    my ($self) = @_;
    my $dbd_options = $self->dbi_options;

    return DBI->connect($self->dbi_options);
};

has dbi_options => (
    isa           => 'ArrayRef',
    is            => 'ro',
    auto_deref    => 1,
    lazy_build    => 1,
    documentation => 'Options passed to DBI->connect()',
);

sub _build_dbi_options {
    my ($self) = @_;
    my $dbd = $self->dbd;
    my $dbd_options = $self->dbd_options;
    my $db = $self->brain // '';

    my @options = (
        "dbi:$dbd:dbname=$db",
        '',
        '',
        $dbd_options,
    );

    return \@options;
}

has _engaged => (
    isa           => 'Bool',
    is            => 'rw',
    default       => 0,
    documentation => 'Have we done setup work to get this database going?',
);

has sth => (
    isa        => 'HashRef',
    is         => 'ro',
    lazy_build => 1,
    documentation => 'A HashRef of prepared DBI statement handles',
);

sub _build_sth {
    my ($self) = @_;
    return Hailo::Storage::Schema->sth($self->dbd, $self->dbh, $self->order);
}

has _boundary_token_id => (
    isa => 'Int',
    is  => 'rw',
);

# bootstrap the database
sub _engage {
    my ($self) = @_;

    if ($self->initialized) {
        my $sth = $self->dbh->prepare(qq[SELECT text FROM info WHERE attribute = ?;]);
        $sth->execute('markov_order');
        my $db_order = $sth->fetchrow_array();

        my $my_order = $self->order;
        if ($my_order != $db_order) {
            if ($self->hailo->_custom_order) {
                die <<"DIE";
You've manually supplied an order of `$my_order' to Hailo but you're
loading a brain that has the order `$db_order'.

Hailo will automatically load the order from existing brains, however
you've constructed Hailo and manually specified an order not
equivalent to the existing order of the database.

Either supply the correct order or omit the order attribute
altogether. We could continue but I'd rather die since you're probably
expecting something I can't deliver.
DIE
            }

            $self->order($db_order);
            $self->hailo->order($db_order);
            $self->hailo->_engine->order($db_order);
        }

        $self->sth->{token_id}->execute(0, '');
        my $id = $self->sth->{token_id}->fetchrow_array;
        $self->_boundary_token_id($id);
    }
    else {
        Hailo::Storage::Schema->deploy($self->dbd, $self->dbh, $self->order);

        my $order = $self->order;
        $self->sth->{set_info}->execute('markov_order', $order);

        $self->sth->{add_token}->execute(0, '');
        $self->sth->{last_token_rowid}->execute();
        my $id = $self->sth->{last_token_rowid}->fetchrow_array();
        $self->_boundary_token_id($id);
    }

    $self->_engaged(1);

    return;
}

sub start_training {
    my ($self) = @_;
    $self->_engage() unless $self->_engaged;
    $self->start_learning();
    return;
}

sub stop_training {
    my ($self) = @_;
    $self->stop_learning();
    return;
}

sub start_learning {
    my ($self) = @_;
    $self->_engage() unless $self->_engaged;

    # start a transaction
    $self->dbh->begin_work;
    return;
}

sub stop_learning {
    my ($self) = @_;
    # finish a transaction
    $self->dbh->commit;
    return;
}

# See if SELECT count(*) FROM info; fails. If not we assume that we
# have an up and running database.
sub initialized {
    my ($self) = @_;
    my $dbh = $self->dbh;

    my ($err, $warn, $res);
    eval {
        # SQLite will warn 'no such table info'
        local $SIG{__WARN__} = sub { $err = $_[0] };

        # If it doesn't warn trust that it dies here
        local ($@, $!);
        $res = $dbh->do("SELECT count(*) FROM info;");
    };

    return (not $err and not $warn and defined $res);
}

# return some statistics
sub totals {
    my ($self) = @_;
    $self->_engage() unless $self->_engaged;

    $self->sth->{token_total}->execute();
    my $token = $self->sth->{token_total}->fetchrow_array - 1;
    $self->sth->{expr_total}->execute();
    my $expr = $self->sth->{expr_total}->fetchrow_array // 0;
    $self->sth->{prev_total}->execute();
    my $prev = $self->sth->{prev_total}->fetchrow_array // 0;
    $self->sth->{next_total}->execute();
    my $next = $self->sth->{next_total}->fetchrow_array // 0;

    return $token, $expr, $prev, $next;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage - A base class for L<Hailo> L<storage|Hailo::Role::Storage> backends

=head1 METHODS

The following methods must to be implemented by subclasses:

=head2 C<_build_dbd>

Should return the name of the database driver (e.g. 'SQLite') which will be
passed to L<DBI|DBI>.

=head2 C<_build_dbd_options>

Subclasses can override this method to add options of their own. E.g:

    override _build_dbd_options => sub {
        return {
            %{ super() },
            sqlite_unicode => 1,
        };
    };

=head2 C<initialized>

Should return a true value if the database has already been created.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason and
Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
