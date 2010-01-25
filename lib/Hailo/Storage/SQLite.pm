package Hailo::Storage::SQLite;

use Moose;
use MooseX::Types::Moose qw<Int Str>;
use DBI;
use DBIx::Perlish;
use List::Util qw<shuffle>;
use List::MoreUtils qw<natatime>;
use namespace::clean -except => 'meta';

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
    init_arg   => undef,
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

    # allow for 50MB of in-memory cache
    $self->_dbh->do('PRAGMA cache_size = 50000');

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

    my @state = (
        'CREATE TABLE info (
            attribute TEXT NOT NULL UNIQUE PRIMARY KEY,
            text      TEXT NOT NULL
        )',
        'CREATE TABLE token (
            token_id INTEGER PRIMARY KEY AUTOINCREMENT,
            text     TEXT NOT NULL
        )',
        'CREATE TABLE expr (
            expr_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            dummy   INTEGER
        )',
        'CREATE TABLE expr_token (
            expr_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            expr_id       INTEGER NOT NULL REFERENCES expr (expr_id),
            token_id      INTEGER NOT NULL REFERENCES token (token_id),
            token_pos     INTEGER NOT NULL
        )',
        'CREATE TABLE next_token (
            pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
            token_id     INTEGER NOT NULL REFERENCES token (token_id)
        )',
        'CREATE TABLE prev_token (
            pos_token_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            expr_id      INTEGER NOT NULL REFERENCES expr (expr_id),
            token_id     INTEGER NOT NULL REFERENCES token (token_id)
        )',
    );
    
    for my $statement (@state) {
        my $sth = $self->_dbh->prepare($statement);
        $sth->execute();
    }

    return;
}

sub add_expr {
    my ($self, %args) = @_;
    my $tokens = $args{tokens};
 
    return if defined $self->_expr_id($tokens);

    # dirty hack, patches welcome
    db_insert 'expr', { dummy => undef };
    my $expr_id = $self->_dbh->selectrow_array('SELECT last_insert_rowid()');

    # add the tokens
    my @token_ids = $self->_add_tokens($tokens);

    for my $pos (0 .. $#{ $tokens }) {
        db_insert 'expr_token', {
            expr_id   => $expr_id,
            token_id  => $token_ids[$pos],
            token_pos => $pos,
        };
    }

    for my $pos_token (qw(next_token prev_token)) {
        next if !defined $args{$pos_token};
        my $token_id = $self->_add_tokens($args{$pos_token});

        if (!defined db_fetch {
            my $t : table = $pos_token;
            $t->expr_id == $expr_id;
            $t->token_id == $token_id;
            return $t->pos_token_id;
        }) {
            db_insert $pos_token, {
                expr_id  => $expr_id,
                token_id => $token_id,
            };
        }
    }
    
    return;
}

sub _expr_id {
    my ($self, $tokens) = @_;
    
    my $first_token = $tokens->[0];
    my @expr_ids = db_fetch {
        expr_token->token_pos == 0;
        expr_token->token_id <- db_fetch {
            token->text eq $first_token;
            return token->token_id;
        };
        return expr_token->expr_id;
    };

    for my $pos (1 .. $#{ $tokens }) {
        return if !@expr_ids;
        my $current_token = $tokens->[$pos];
        
        # limit the number of SQL variables we use, sqlite only allows 999
        my $iter = natatime(997, @expr_ids);
        my @fewer_ids;
        while (my @ids = $iter->()) {
            push @fewer_ids, db_fetch {
                expr_token->token_pos == $pos;
                expr_token->expr_id <- @ids;
                expr_token->token_id <- db_fetch {
                    token->text eq $current_token;
                    return token->token_id;
                };
                return expr_token->expr_id;
            };
        }
        @expr_ids = @fewer_ids;
    }
    return $expr_ids[0] if @expr_ids == 1;

    return;
}

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
            push @token_ids, db_fetch {
                token->text eq $token;
                return token->token_id;
            };
        }
    }

    return @token_ids > 1 ? @token_ids : $token_ids[0];
}

sub token_exists {
    my ($self, $token) = @_;
    
    return 1 if defined db_fetch {
        token->text eq $token;
        return token->token_id;
    };
    return;
}

sub random_expr {
    my ($self, $token) = @_;

    my $token_id = $self->_add_tokens($token);
    my @positions = shuffle(0 .. $self->order-1);
    my @expr;

    my @expr_ids;
    for my $pos (@positions) {
        @expr_ids = shuffle db_fetch {
            expr_token->token_pos == $pos;
            expr_token->token_id == $token_id;
            return expr_token->expr_id;
        };
        next if !@expr_ids;
        
        my $expr_id = shift @expr_ids;
        @expr = db_fetch {
            my $t : token;
            my $e : expr_token;
            $e->expr_id == $expr_id;
            join $t * $e <= db_fetch {
                $t->token_id == $e->token_id;
            };
            sort $e->token_pos;
            return $t->text;
        };
        last if @expr;
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
    my ($self, $table, $tokens) = @_;

    my $expr_id = $self->_expr_id($tokens);
    return db_fetch {
        token->token_id <- db_fetch {
            my $t : table = $table;
            $t->expr_id eq $expr_id;
            return $t->token_id;
        };
        return token->text;
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

Importing 1000 lines of IRC output takes about 6 minutes on my laptop.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
