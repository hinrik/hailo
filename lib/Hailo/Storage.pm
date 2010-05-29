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
        # Check the order we've been given and retrieve it from the
        # database if there's nothing odd going on.
        $self->_engage_initialized_check_and_set_order;

        # Likewise for the Tokenizer
        $self->_engage_initialized_check_and_set_tokenizer;

        $self->sth->{token_id}->execute(0, '');
        my $id = $self->sth->{token_id}->fetchrow_array;
        $self->_boundary_token_id($id);
    }
    else {
        Hailo::Storage::Schema->deploy($self->dbd, $self->dbh, $self->order);

        # Set metadata in the database for use by subsequent
        # invocations
        {
            # Don't change order again
            my $order = $self->order;
            $self->sth->{set_info}->execute('markov_order', $order);

            # Warn if the tokenizer changes
            my $tokenizer = $self->tokenizer_class;
            $self->sth->{set_info}->execute('tokenizer_class', $tokenizer);
        }

        $self->sth->{add_token}->execute(0, '');
        $self->sth->{last_token_rowid}->execute();
        my $id = $self->sth->{last_token_rowid}->fetchrow_array();
        $self->_boundary_token_id($id);
    }

    $self->_engaged(1);

    return;
}

sub _engage_initialized_check_and_set_order {
    my ($self) = @_;

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

    return;
}

sub _engage_initialized_check_and_set_tokenizer {
    my ($self) = @_;

    my $sth = $self->dbh->prepare(qq[SELECT text FROM info WHERE attribute = ?;]);
    $sth->execute('tokenizer_class');
    my $db_tokenizer_class = $sth->fetchrow_array;
    my $my_tokenizer_class = $self->tokenizer_class;

    # defined() because we can't count on old brains having this
    if (defined $db_tokenizer_class
        and $my_tokenizer_class ne $db_tokenizer_class) {
        if ($self->hailo->_custom_tokenizer_class) {
            die <<"DIE";
You've manually supplied a tokenizer class `$my_tokenizer_class' to
Hailo, but you're loading a brain that has the tokenizer class
`$db_tokenizer_class'.

Hailo will automatically load the tokenizer class from existing
brains, however you've constructed Hailo and manually specified an
tokenizer class not equivalent to the existing tokenizer class of the
database.

Either supply the correct tokenizer class or omit the order attribute
altogether. We could continue but I'd rather die since you're probably
expecting something I can't deliver.
DIE
        }

        $self->tokenizer_class($db_tokenizer_class);
        $self->hailo->tokenizer_class($db_tokenizer_class);
    }

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

=head1 Comparison of backends

This benchmark shows how the backends compare when training on the
small testsuite dataset as reported by the F<utils/hailo-benchmark>
utility (found in the distribution):

                         Rate DBD::Pg DBD::mysql DBD::SQLite/file DBD::SQLite/memory
    DBD::Pg            2.22/s      --       -33%             -49%               -56%
    DBD::mysql         3.33/s     50%         --             -23%               -33%
    DBD::SQLite/file   4.35/s     96%        30%               --               -13%
    DBD::SQLite/memory 5.00/s    125%        50%              15%                 --

Under real-world workloads SQLite is much faster than these results
indicate since the time it takes to train/reply is relative to the
existing database size. Here's how long it took to train on a 214,710
line IRC log on a Linode 1080 with Hailo 0.18:

=over

=item * SQLite

    real    8m38.285s
    user    8m30.831s
    sys     0m1.175s

=item * MySQL

    real    48m30.334s
    user    8m25.414s
    sys     4m38.175s

=item * PostgreSQL

    real    216m38.906s
    user    11m13.474s
    sys     4m35.509s

=back

In the case of PostgreSQL it's actually much faster to first train
with SQLite, dump that database and then import it with L<psql(1)>,
see L<failo's README|http://github.com/hinrik/failo> for how to do
that.

However when replying with an existing database (using
F<utils/hailo-benchmark-replies>) yields different results. SQLite can
reply really quickly without being warmed up (which is the typical
usecase for chatbots) but once PostgreSQL and MySQL are warmed up they
start replying faster:

Here's a comparison of doing 10 replies:

                        Rate PostgreSQL MySQL SQLite-file SQLite-file-28MB SQLite-memory
    PostgreSQL        71.4/s         --  -14%        -14%             -29%          -50%
    MySQL             83.3/s        17%    --          0%             -17%          -42%
    SQLite-file       83.3/s        17%    0%          --             -17%          -42%
    SQLite-file-28MB 100.0/s        40%   20%         20%               --          -30%
    SQLite-memory      143/s       100%   71%         71%              43%            --

In this test MySQL uses around 28MB of memory (using Debian's
F<my-small.cnf>) and PostgreSQL around 34MB. Plain SQLite uses 2MB of
cache but it's also tested with 28MB of cache as well as with the
entire database in memory.

But doing 10,000 replies is very different:

                       Rate SQLite-file PostgreSQL SQLite-file-28MB MySQL SQLite-memory
    SQLite-file      85.1/s          --        -7%             -18%  -27%          -38%
    PostgreSQL       91.4/s          7%         --             -12%  -21%          -33%
    SQLite-file-28MB  103/s         21%        13%               --  -11%          -25%
    MySQL             116/s         37%        27%              13%    --          -15%
    SQLite-memory     137/s         61%        50%              33%   18%            --

Once MySQL gets more memory (using Debian's F<my-large.cnf>) and a
chance to warm it starts yielding better results (I couldn't find out
how to make PostgreSQL take as much memory as it wanted):

                   Rate         MySQL SQLite-memory
    MySQL         121/s            --          -12%
    SQLite-memory 138/s           14%            --

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason and
Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
