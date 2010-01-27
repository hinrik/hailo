package Hailo::Storage::SQLite;
use 5.10.0;
use Moose;
use MooseX::Types::Moose qw<Int Str>;
use DBI;
use List::Util qw<shuffle>;
use Data::Section qw(-setup);
use Template;
use namespace::clean -except => [ qw(meta section_data) ];

our $VERSION = '0.01';

has file => (
    isa      => Str,
    is       => 'ro',
    required => 1,
);

has order => (
    isa => Int,
    is  => 'rw',
);

has _dbh => (
    isa        => 'DBI::db',
    is         => 'ro',
    lazy_build => 1,
);

with 'Hailo::Storage';

sub _build__dbh {
    my ($self) = @_;

    return DBI->connect(
        "dbi:SQLite:dbname=".$self->file,
        '',
        '', 
        { sqlite_unicode => 1, RaiseError => 1 },
    );
}

sub BUILD {
    my ($self) = @_;
    my $dbh = $self->_dbh;

    if ($self->_exists_db) {
        my $st = "SELECT text FROM info WHERE attribute = 'markov_order'";
        my $order = $dbh->selectrow_array($st);
        $self->order($order);
    }
    else {
        $self->_create_db();
        my $order = $self->order;
        $dbh->do("INSERT INTO info (attribute, text) VALUES ('markov_order', $order)");
    }

    return;
}

sub start_training {
    my ($self) = @_;

    # don't fsync till we're done
    $self->_dbh->do('PRAGMA synchronous=OFF;');

    #start a transaction
    $self->_dbh->begin_work;

    return;
}

sub stop_training {
    my ($self) = @_;

    # finish a transaction
    $self->_dbh->commit;

    return;
}

sub _exists_db {
    my ($self) = @_;

    return -s $self->file;
}

sub _create_db {
    my ($self) = @_;

    my @statements = $self->_get_create_db_sql;

    $self->_dbh->do($_) for @statements;

    return;
}

sub _get_create_db_sql {
    my ($self) = @_;
    my $sql;

    for my $section (qw(info token expr next_token prev_token indexes)) {
        my $template = $self->section_data($section);
        Template->new->process(
            $template,
            {
                orders => [ 0 .. $self->order-1 ],
            },
            \$sql,
        );
    }

    return ($sql =~ /\s*(.*?);/gs);
}

sub _expr_text {
    my ($self, $tokens) = @_;
    return join $self->token_separator, @$tokens;
}

# add a new expression to the database
sub add_expr {
    my ($self, %args) = @_;
    my $dbh       = $self->_dbh;
    my $tokens    = $args{tokens};
    my $expr_text = $self->_expr_text($tokens);
    my $expr_id   = $self->_expr_id($expr_text);

    if (!defined $expr_id) {
        # add the tokens
        my @token_ids = $self->_add_tokens($tokens);

        # add the expression
        my @columns = map { "token${_}_id" } 0 .. $self->order-1;
        local $" = ', ';
        $_ = $dbh->prepare("INSERT INTO expr (@columns, expr_text) VALUES (@token_ids, ?)");
        $_->execute($expr_text);

        # get the new expr id
        $expr_id = $self->_last_expr_rowid();
    }

    # add next/previous tokens for this expression, if any
    for my $pos_token (qw(next_token prev_token)) {
        next if !defined $args{$pos_token};
        my $token_id = $self->_add_tokens($args{$pos_token});

        $_ = "SELECT count FROM $pos_token WHERE expr_id == $expr_id AND token_id == $token_id";
        my $count = $dbh->selectrow_array($_);

        if (defined $count) {
            my $inc = $count++;
            $_ = $dbh->prepare("UPDATE $pos_token SET count = $inc WHERE expr_id == $expr_id AND token_id == $token_id");
            $_->execute();
        }
        else {
            $_ = $dbh->prepare("INSERT INTO $pos_token (expr_id, token_id, count) VALUES ($expr_id, $token_id, 1)");
            $_->execute();
        }
    }

    return;
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $expr_text) = @_;
    $_ = "SELECT expr_id FROM expr where expr_text = ?";
    return scalar $self->_dbh->selectrow_array($_, {}, $expr_text);
}

# add tokens and/or return their ids
sub _add_tokens {
    my ($self) = shift;
    my $tokens = ref $_[0] eq 'ARRAY' ? shift : [@_];
    my $dbh = $self->_dbh;
    my @token_ids;

    for my $token (@$tokens) {
        $_ = "SELECT token_id FROM token WHERE text = ?";
        my $old_token_id = $dbh->selectrow_array($_, {}, $token);

        if (defined $old_token_id) {
            push @token_ids, $old_token_id;
        }
        else {
            $_ = "INSERT INTO token (text) VALUES (?)";
            $dbh->do($_, {}, $token);
            push @token_ids, $self->_last_token_rowid();
        }
    }

    return @token_ids > 1 ? @token_ids : $token_ids[0];
}

# return the primary key of the last inserted row
sub _last_expr_rowid  { return shift->_dbh->selectrow_array('SELECT last_insert_rowid()') }
sub _last_token_rowid { return shift->_dbh->selectrow_array('SELECT last_insert_rowid()') }

sub token_exists {
    my ($self, $token) = @_;
    my $dbh = $self->_dbh;

    my $_ = "SELECT token_id FROM token WHERE text = ?";
    return defined $dbh->selectrow_array($_, {}, $token);
}

sub _split_expr {
    my ($self, $expr) = @_;
    return split /\t/, $expr;
}

# return a random expression containing the given token
sub random_expr {
    my ($self, $token) = @_;
    my $dbh = $self->_dbh;

    my $token_id = $self->_add_tokens($token);
    my @expr;

    # try the positions in a random order
    for my $pos (shuffle 0 .. $self->order-1) {
        my $column = "token${pos}_id";

        # find all expressions which include the token at this position
        $_ = "SELECT expr_id FROM expr WHERE $column = ?";
        my $expr_ids = $dbh->selectcol_arrayref($_, {}, $token_id);

        # try the next position if no expression has it at this one
        next if !@$expr_ids;

        # we found some, let's pick a random one and return its tokens
        my $expr_id = $expr_ids->[rand @$expr_ids];
        $_ = "SELECT expr_text FROM expr WHERE expr_id = ?";
        my $expr_text = $dbh->selectrow_array($_, {}, $expr_id);
        @expr = $self->_split_expr($expr_text);

        last;
    }

    return @expr;
}

sub next_tokens {
    my ($self, $tokens) = @_;
    return $self->_pos_tokens('next_token', $tokens);
}

sub prev_tokens {
    my ($self, $tokens) = @_;
    return $self->_pos_tokens('prev_token', $tokens);
}

sub _pos_tokens {
    my ($self, $pos_table, $tokens) = @_;
    my $dbh = $self->_dbh;

    my $expr_text = $self->_expr_text($tokens);
    my $expr_id = $self->_expr_id($expr_text);

    $_ = "SELECT t.text, p.count FROM token t INNER JOIN $pos_table p ON p.token_id = t.token_id WHERE p.expr_id = ?";
    my $ugly_hash = $dbh->selectall_hashref($_, 'text', {}, $expr_id);
    my %clean_hash = map { +$_ => $ugly_hash->{$_}{count} } keys %$ugly_hash;
    return \%clean_hash;
}

sub save {
    # no op
}

__PACKAGE__->meta->make_immutable;

1;

=encoding utf8

=head1 NAME

Hailo::Storage::SQLite - A storage backend for L<Hailo|Hailo> using
L<DBD::SQLite|DBD::SQLite>

=head1 DESCRIPTION

This backend maintains information in an SQLite database.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ info ]__
CREATE TABLE info (
    attribute TEXT NOT NULL UNIQUE PRIMARY KEY,
    text      TEXT NOT NULL
);
__[ token ]__
CREATE TABLE token (
    token_id INTEGER PRIMARY KEY AUTOINCREMENT,
    text     TEXT NOT NULL
);
__[ expr ]__
CREATE TABLE expr (
    expr_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    expr_text TEXT NOT NULL UNIQUE
);
[% FOREACH i IN orders %]
ALTER TABLE expr ADD token[% i %]_id INTEGER REFERENCES token (token_id);
[% END %]
__[ next_token ]__
CREATE TABLE next_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ prev_token ]__
CREATE TABLE prev_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ indexes ]__
CREATE INDEX token_text ON token (text);
CREATE INDEX expr_token0_id on expr (token0_id);
CREATE INDEX expr_token1_id on expr (token1_id);
CREATE INDEX expr_token2_id on expr (token2_id);
CREATE INDEX expr_token3_id on expr (token3_id);
CREATE INDEX expr_token4_id on expr (token4_id);
CREATE INDEX next_token_expr_id ON next_token (expr_id);
CREATE INDEX prev_token_expr_id ON prev_token (expr_id);
