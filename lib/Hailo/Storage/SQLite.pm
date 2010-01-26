package Hailo::Storage::SQLite;
use 5.10.0;
use Moose;
use MooseX::Types::Moose qw<Int Str>;
use DBI;
use DBIx::Perlish;
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

    DBIx::Perlish::init($self->_dbh);

    if (-s $self->file) {
        $self->order(db_fetch {
            info->attribute eq 'markov_order';
            return info->text;
        });
    }
    else {
        $self->_create_db();

        db_insert 'info', {
            attribute => 'markov_order',
            text      => $self->order,
        };
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

sub _create_db {
    my ($self) = @_;

    my @statements = $self->_get_create_db_sql;

    $self->_dbh->do($_) for @statements;

    return;
}

sub _get_create_db_sql {
    my ($self) = @_;
    my $sql;

    for my $table (qw(info token expr next_token prev_token)) {
        my $template = $self->section_data( "table_$table" );
        Template->new->process(
            $template,
            {
                orders => [ 0 .. $self->order-1 ],
            },
            \$sql,
        );
    }

    my (@sql) = $sql =~ /\s*(.*?);/gs;
}

sub _expr_text {
    my ($self, $tokens) = @_;
    return join $self->token_separator, @$tokens;
}

# add a new expression to the database
sub add_expr {
    my ($self, %args) = @_;
    my $tokens = $args{tokens};

    my $expr_text = $self->_expr_text($tokens);
    my $expr_id = $self->_expr_id($expr_text);

    if (!defined $expr_id) {
        # add the tokens
        my @token_ids = $self->_add_tokens($tokens);

        # add the expression
        db_insert 'expr', {
            (map { +"token${_}_id" => $token_ids[$_] } 0 .. $self->order-1),
            expr_text => $expr_text,
        };

        # get the new expr id
        $expr_id = $self->_last_expr_rowid();
    }

    # add next/previous tokens for this expression, if any
    for my $pos_token (qw(next_token prev_token)) {
        next if !defined $args{$pos_token};
        my $token_id = $self->_add_tokens($args{$pos_token});

        my $count = db_fetch {
            my $t : table = $pos_token;
            $t->expr_id == $expr_id;
            $t->token_id == $token_id;
            return $t->count;
        };

        if (defined $count) {
            db_update {
                my $t : table = $pos_token;
                $t->expr_id == $expr_id;
                $t->token_id == $token_id;
                $t->count = $t->count+1;
            };
        }
        else {
            db_insert $pos_token, {
                expr_id  => $expr_id,
                token_id => $token_id,
                count    => 1,
            };
        }
    }

    return;
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $expr_text) = @_;
    
    return db_fetch {
        expr->expr_text eq $expr_text;
        return expr->expr_id;
    };
}

# add tokens and/or return their ids
sub _add_tokens {
    my ($self) = shift;
    my $tokens = ref $_[0] eq 'ARRAY' ? shift : [@_];
    my @token_ids;

    for my $token (@$tokens) {
        my $old_token_id = db_fetch {
            token->text eq $token;
            return token->token_id;
        };
        
        if (defined $old_token_id) {
            push @token_ids, $old_token_id;
        }
        else {
            db_insert 'token', { text => $token };
            push @token_ids, $self->_last_token_rowid();
        }
    }

    return @token_ids > 1 ? @token_ids : $token_ids[0];
}

# return the primary key of the last inserted row
sub _last_expr_rowid  { shift->_dbh->selectrow_array('SELECT last_insert_rowid()') }
sub _last_token_rowid { shift->_dbh->selectrow_array('SELECT last_insert_rowid()') }

sub token_exists {
    my ($self, $token) = @_;
    
    return defined db_fetch {
        token->text eq $token;
        return token->token_id;
    };
}

sub _split_expr {
    my ($self, $expr) = @_;
    return split /\t/, $expr;
}

# return a random expression containing the given token
sub random_expr {
    my ($self, $token) = @_;

    my $token_id = $self->_add_tokens($token);
    my @expr;

    # try the positions in a random order
    POSITION: for my $pos (shuffle 0 .. $self->order-1) {
        my $column = "token${pos}_id";

        # find all expressions which include the token at this position
        my @expr_ids = shuffle db_fetch {
            expr->$column == $token_id;
            return expr->expr_id;
        };

        # try the next position if no expression has it at this one
        next if !@expr_ids;

        # we found some, let's pick a random one and return its tokens
        my $expr_id = (shuffle @expr_ids)[0];
        my $expr_text = db_fetch {
            expr->expr_id == $expr_id;
            return expr->expr_text;
        };

        @expr = $self->_split_expr($expr_text);
        last POSITION;
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

    my $expr_text = $self->_expr_text($tokens);
    my $expr_id = $self->_expr_id($expr_text);
    return db_fetch {
        my $pos : table = $pos_table;
        my $tok : token;
        $pos->expr_id == $expr_id;
        join $pos * $tok => db_fetch {
            $pos->token_id == $tok->token_id;
        };
        return -k $tok->text, $pos->count;
    };
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

It uses very little memory, but training is very slow. Some optimizations
are yet to be made (crafting more efficient queries, adding indexes, etc).

Importing 1000 lines of IRC output takes 1 minutes and 5 seconds on my laptop
(2.53 GHz Core 2 Duo).

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
__[ table_info ]__
CREATE TABLE info (
    attribute TEXT NOT NULL UNIQUE PRIMARY KEY,
    text      TEXT NOT NULL
);
__[ table_token ]__
CREATE TABLE token (
    token_id SERIAL,
    text     TEXT NOT NULL
);
__[ table_expr ]__
CREATE TABLE expr (
    expr_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    expr_text TEXT NOT NULL UNIQUE
);
[% FOREACH i IN orders %]
ALTER TABLE expr ADD token[% i %]_id INTEGER REFERENCES token (token_id);
[% END %]
__[ table_next_token ]__
CREATE TABLE next_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
__[ table_prev_token ]__
CREATE TABLE prev_token (
    pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
    token_id     INTEGER NOT NULL REFERENCES token (token_id),
    count        INTEGER NOT NULL
);
