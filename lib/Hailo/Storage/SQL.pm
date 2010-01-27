package Hailo::Storage::SQL;

use 5.10.0;
use Moose;
use MooseX::Types::Moose qw<HashRef Int Str>;
use DBI;
use List::Util qw<shuffle>;
use Data::Section qw(-setup);
use Template;
use namespace::clean -except => [ qw(meta
                                     section_data
                                     section_data_names
                                     merged_section_data
                                     merged_section_data_names) ];

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

has _sth => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
);

with 'Hailo::Storage';

# our statement handlers
sub _build__sth {
    my ($self) = @_;

    my $sections = $self->_sth_sections();
    my %state;
    while (my ($name, $options) = each %$sections) {
        my $section = $options->{section} // $name;
        my %options = %{ $options->{options} // {} };
        my $template = $self->section_data("query_$section");
        my $sql;
        Template->new->process(
            $template,
            {
                orders => [ 0 .. $self->order-1 ],
                %options,
            },
            \$sql,
        );
        $state{$name} = $sql;
    }

    $state{$_} = $self->_dbh->prepare($state{$_}) for keys %state;
    return \%state;
}

sub _sth_sections {
    my ($self) = @_;
    my %sections;

    my @plain_sections = map { s[^query_][]; $_ }
                         # () sections are magical
                         grep { /^query_/ and not /\(.*?\)/ }
                         $self->section_data_names;

    $sections{$_} = undef for @plain_sections;

    for my $np (qw(next_token prev_token)) {
        for my $ciag (qw(count inc add get)) {
            $sections{$np . '_' . $ciag} = {
                section => "(next_token|prev_token)_$ciag",
                options => { table => $np },
            };
        }
    }

    for my $order (0 .. $self->order-1) {
        $sections{"expr_id_token${order}_id"} = {
            section => 'expr_id_token(NUM)_id',
            options => { column => "token${order}_id" },
        };
    }

    {
        my @columns = map { "token${_}_id" } 0 .. $self->order-1;
        my @ids = join(', ', ('?') x @columns);
        $sections{add_expr} = {
            section => '(add_expr)',
            options => {
                columns => join(', ', @columns),
                ids     => join(', ', @ids),
            }
        }
    }

    return \%sections;
}

sub BUILD {
    my ($self) = @_;

    if ($self->_exists_db) {
        $self->_sth->{get_order}->execute();
        my $order = $self->_sth->{get_order}->fetchrow_array();
        $self->order($order);
    }
    else {
        $self->_create_db();
        my $order = $self->order;
        $self->_sth->{set_order}->execute($order);
    }

    return;
}

sub start_training {
    my ($self) = @_;

    # start a transaction
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

    for my $section (qw(info token expr next_token prev_token indexes)) {
        my $template = $self->section_data("table_$section");
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
    my $tokens    = $args{tokens};
    my $expr_text = $self->_expr_text($tokens);
    my $expr_id   = $self->_expr_id($expr_text);

    if (!defined $expr_id) {
        # add the tokens
        my @token_ids = $self->_add_tokens($tokens);

        $expr_id = $self->_add_expr(\@token_ids, $expr_text);
    }

    # add next/previous tokens for this expression, if any
    for my $pos_token (qw(next_token prev_token)) {
        next if !defined $args{$pos_token};
        my $token_id = $self->_add_tokens($args{$pos_token});

        my $get_count = "${pos_token}_count";
        $self->_sth->{$get_count}->execute($expr_id, $token_id);
        my $count = $self->_sth->{$get_count}->fetchrow_array;

        if (defined $count) {
            my $new_count = $count++;
            my $inc_count = "${pos_token}_inc";
            $self->_sth->{$inc_count}->execute($new_count, $expr_id, $token_id);
        }
        else {
            my $add_count = "${pos_token}_add";
            $self->_sth->{$add_count}->execute($expr_id, $token_id);
        }
    }

    return;
}

sub _add_expr {
    my ($self, $token_ids, $expr_text) = @_;

    # add the expression
    $self->_sth->{add_expr}->execute(@$token_ids, $expr_text);

    # get the new expr id
    $self->_sth->{last_expr_rowid}->execute();
    return $self->_sth->{last_expr_rowid}->fetchrow_array;
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $expr_text) = @_;
    $self->_sth->{expr_id}->execute($expr_text);
    return scalar $self->_sth->{expr_id}->fetchrow_array();
}

# add tokens and/or return their ids
sub _add_tokens {
    my ($self) = shift;
    my $tokens = ref $_[0] eq 'ARRAY' ? shift : [@_];
    my @token_ids;

    for my $token (@$tokens) {
        $self->_sth->{token_id}->execute($token);
        my $old_token_id = $self->_sth->{token_id}->fetchrow_array();

        if (defined $old_token_id) {
            push @token_ids, $old_token_id;
        }
        else {
            push @token_ids, => $self->_add_token($token);
        }
    }

    return @token_ids > 1 ? @token_ids : $token_ids[0];
}

sub _add_token {
    my ($self, $token) = @_;

    $self->_sth->{add_token}->execute($token);
    $self->_sth->{last_token_rowid}->execute();
    return $self->_sth->{last_token_rowid}->fetchrow_array;
}

sub token_exists {
    my ($self, $token) = @_;

    $self->_sth->{token_id}->execute($token);
    return defined $self->_sth->{token_id}->fetchrow_array();
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
        $self->_sth->{"expr_id_$column"}->execute($token_id);
        my $expr_ids = $self->_sth->{"expr_id_$column"}->fetchall_arrayref();
        $expr_ids = [ map { $_->[0] } @$expr_ids ];

        # try the next position if no expression has it at this one
        next if !@$expr_ids;

        # we found some, let's pick a random one and return its tokens
        my $expr_id = $expr_ids->[rand @$expr_ids];
        $self->_sth->{expr_text}->execute($expr_id);
        my $expr_text = $self->_sth->{expr_text}->fetchrow_array();
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

    $self->_sth->{"${pos_table}_get"}->execute($expr_id);
    my $ugly_hash = $self->_sth->{"${pos_table}_get"}->fetchall_hashref('text');
    my %clean_hash = map { +$_ => $ugly_hash->{$_}{count} } keys %$ugly_hash;
    return \%clean_hash;
}

sub save {
    # no op
}

1;

=encoding utf8

=head1 NAME

Hailo::Storage::SQL - A skeleton SQL backend meant to be subclassed

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

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
    token_id INTEGER PRIMARY KEY AUTOINCREMENT,
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
__[ table_indexes ]__
CREATE INDEX token_text ON token (text);
CREATE INDEX expr_token0_id on expr (token0_id);
CREATE INDEX expr_token1_id on expr (token1_id);
CREATE INDEX expr_token2_id on expr (token2_id);
CREATE INDEX expr_token3_id on expr (token3_id);
CREATE INDEX expr_token4_id on expr (token4_id);
CREATE INDEX next_token_expr_id ON next_token (expr_id);
CREATE INDEX prev_token_expr_id ON prev_token (expr_id);
__[ query_get_order ]__
SELECT text FROM info WHERE attribute = 'markov_order';
__[ query_set_order ]__
INSERT INTO info (attribute, text) VALUES ('markov_order', ?);
__[ query_expr_id ]__
SELECT expr_id FROM expr WHERE expr_text = ?;
__[ query_expr_id_token(NUM)_id ]__
SELECT expr_id FROM expr WHERE [% column %] = ?;
__[ query_expr_text ]__
SELECT expr_text FROM expr WHERE expr_id = ?;
__[ query_token_id ]__
SELECT token_id FROM token WHERE text = ?;
__[ query_add_token ]__
INSERT INTO token (text) VALUES (?);
__[ query_last_expr_rowid ]_
SELECT expr_id  FROM expr  ORDER BY expr_id  DESC LIMIT 1;
__[ query_last_token_rowid ]__
SELECT token_id FROM token ORDER BY token_id DESC LIMIT 1;
__[ query_(next_token|prev_token)_count ]__
SELECT count FROM [% table %] WHERE expr_id = ? AND token_id = ?;
__[ query_(next_token|prev_token)_inc ]__
UPDATE [% table %] SET count = ? WHERE expr_id = ? AND token_id = ?
__[ query_(next_token|prev_token)_add ]__
INSERT INTO [% table %] (expr_id, token_id, count) VALUES (?, ?, 1);
__[ query_(next_token|prev_token)_get ]__
SELECT t.text, p.count
  FROM token t
INNER JOIN [% table %] p
        ON p.token_id = t.token_id
     WHERE p.expr_id = ?;
__[ query_(add_expr) ]__
INSERT INTO expr ([% columns %], expr_text) VALUES ([% ids %], ?);
