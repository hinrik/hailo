package Hailo::Storage::Mixin::DBD;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw<ArrayRef HashRef Int Str Bool>;
use DBI;
use List::Util qw<shuffle>;
use List::MoreUtils qw<uniq>;
use Data::Section qw(-setup);
use Template;
use namespace::clean -except => [ qw(meta
                                     section_data
                                     section_data_names
                                     merged_section_data
                                     merged_section_data_names) ];

our $VERSION = '0.11';

with qw(Hailo::Role::Generic
        Hailo::Role::Storage
        Hailo::Role::Log);

has dbh => (
    isa        => 'DBI::db',
    is         => 'ro',
    lazy_build => 1,
);

has dbd => (
    isa           => Str,
    is            => 'ro',
    documentation => "The DBD::* driver we're using",
);

sub _build_dbh {
    my ($self) = @_;
    my $dbd_options = $self->dbi_options;

    return DBI->connect($self->dbi_options);
};

has dbi_options => (
    isa => ArrayRef,
    is => 'ro',
    auto_deref => 1,
    lazy_build => 1,
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

has dbd_options => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
);

sub _build_dbd_options {
    my ($self) = @_;
    return {
        RaiseError => 1
    };
}

has _engaged => (
    isa           => Bool,
    is            => 'rw',
    default       => 0,
    documentation => "Have we done setup work to get this database going?",
);

has sth => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
);

has _boundary_token_id => (
    isa => Int,
    is  => 'rw',
);

# our statement handlers
sub _build_sth {
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
                dbd    => $self->dbd,
                %options,
            },
            \$sql,
        );
        $state{$name} = $sql;
    }

    # hack to make it easy to add WHERE clauses in a FOREACH
    s/\s*AND\s*$/;/ for values %state;

    $state{$_} = $self->dbh->prepare($state{$_}) for keys %state;
    return \%state;
}

sub _sth_sections {
    my ($self) = @_;
    my %sections;

    # () sections are magical
    my @plain_sections = grep { /^query_/ and not /\(.*?\)/ } $self->section_data_names;
    s[^query_][] for @plain_sections;

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
        $sections{"expr_by_token${order}_id"} = {
            section => 'expr_by_token(NUM)_id',
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

sub _engage {
    my ($self) = @_;

    if ($self->_exists_db) {
        $self->sth->{get_order}->execute();
        my $order = $self->sth->{get_order}->fetchrow_array();
        $self->order($order);

        $self->sth->{token_id}->execute('');
        my $id = $self->sth->{token_id}->fetchrow_array;
        $self->_boundary_token_id($id);
    }
    else {
        $self->_create_db();

        my $order = $self->order;
        $self->sth->{set_order}->execute($order);

        $self->sth->{add_token}->execute('');
        $self->sth->{last_token_rowid}->execute();
        my $id = $self->sth->{last_token_rowid}->fetchrow_array();
        $self->_boundary_token_id($id);
    }

    $self->_engaged(1);

    return;
}

sub start_training {
    my ($self) = @_;
    $self->_engage() if !$self->_engaged;
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
    $self->_engage() if !$self->_engaged;

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

sub _create_db {
    my ($self) = @_;
    my @statements = $self->_get_create_db_sql;

    for (@statements) {
        if ($self->meh->is_trace()) {
            #$self->meh->trace( sprintf "Creating database table for '%s': %s", $self->dbd, $_ );
        }
        $self->dbh->do($_);
    }

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
                columns => join(', ', map { "token${_}_id" } 0 .. $self->order-1),
                orders  => [ 0 .. $self->order-1 ],
                dbd     => $self->dbd,
            },
            \$sql,
        );
    }

    return ($sql =~ /\s*(.*?);/gs);
}

sub make_reply {
    my ($self, $key_tokens) = @_;
    my $order = $self->order;

    $self->_engage() if !$self->_engaged;
    my @key_ids = map { $self->_token_id($_) } @$key_tokens;
    @key_ids = $self->_find_rare_tokens(\@key_ids);
    my $key_token_id = shift @key_ids;

    my ($orig_expr_id, @token_ids) = $self->_random_expr($key_token_id);
    return if !defined $orig_expr_id; # we don't know anything yet
    my $repeat_limit = $self->repeat_limit;
    my $expr_id = $orig_expr_id;

    # construct the end of the reply
    my $i = 0;
    while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit and uniq(@token_ids) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }
        my $next_id = $self->_pos_token('next', $expr_id, \@key_ids);
        last if $next_id eq $self->_boundary_token_id;
        push @token_ids, $next_id;
        $expr_id = $self->_expr_id([@token_ids[-$order..-1]]);
    } continue {
        $i++;
    }

    $expr_id = $orig_expr_id;

    # construct the beginning of the reply
    $i = 0; while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit and uniq(@token_ids) <= $order) ||
             ($i >= $repeat_limit * 3))) {
            last;
        }

        my $prev_id = $self->_pos_token('prev', $expr_id, \@key_ids);
        last if $prev_id eq $self->_boundary_token_id;
        unshift @token_ids, $prev_id;
        $expr_id = $self->_expr_id([@token_ids[0..$order-1]]);
    } continue {
        $i++;
    }

    # translate token ids to token text
    my (%ids, @reply);
    for my $id (@token_ids) {
        if (!exists $ids{$id}) {
            $self->sth->{token_text}->execute($id);
            $ids{$id} = $self->sth->{token_text}->fetchrow_array;
        }
        push @reply, $ids{$id};
    }
    return \@reply;
}

sub learn_tokens {
    my ($self, $tokens) = @_;
    my $order = $self->order;

    # a cache of token ids
    my %token_ids;

    for my $token (@$tokens) {
        next if exists $token_ids{$token};
        $token_ids{$token} = $self->_token_id_add($token);
    }

    for my $i (0 .. @$tokens - $order) {
        my @expr = map { $token_ids{ $tokens->[$_] } } ($i .. $i+$order-1);
        my $expr_id = $self->_expr_id(\@expr);
        $expr_id = $self->_add_expr(\@expr) if !defined $expr_id;

        # add next token for this expression, if any
        if ($i < @$tokens - $order) {
            my $next_id = $token_ids{ $tokens->[$i+$order] };
            $self->_inc_link('next_token', $expr_id, $next_id);
        }

        # add previous token for this expression, if any
        if ($i > 0) {
            my $prev_id = $token_ids{ $tokens->[$i-1] };
            $self->_inc_link('prev_token', $expr_id, $prev_id);
        }

        # add boundary tokens if appropriate
        my $b = $self->_boundary_token_id;
        $self->_inc_link('prev_token', $expr_id, $b) if $i == 0;
        $self->_inc_link('next_token', $expr_id, $b) if $i == @$tokens-$order;
    }

    return;
}

# sort token ids based on how rare they are
sub _find_rare_tokens {
    my ($self, $token_ids) = @_;

    my %rare;
    for my $id (@$token_ids) {
        $self->sth->{token_count}->execute($id);
        my $count = $self->sth->{token_count}->fetchall_arrayref;
        $rare{$id} = scalar @$count;
    }

    my @ids = sort { $rare{$a} <=> $rare{$b} } keys %rare;
    return @ids;
}

sub _inc_link {
    my ($self, $type, $expr_id, $token_id) = @_;

    $self->sth->{"${type}_count"}->execute($expr_id, $token_id);
    my $count = $self->sth->{"${type}_count"}->fetchrow_array;

    if (defined $count) {
        my $new_count = $count++;
        $self->sth->{"${type}_inc"}->execute($new_count, $expr_id, $token_id);
    }
    else {
        $self->sth->{"${type}_add"}->execute($expr_id, $token_id);
    }

    return;
}

sub _add_expr {
    my ($self, $token_ids) = @_;
    # add the expression
    $self->sth->{add_expr}->execute(@$token_ids);

    # get the new expr id
    $self->sth->{last_expr_rowid}->execute();
    return $self->sth->{last_expr_rowid}->fetchrow_array;
}

# look up an expression id based on tokens
sub _expr_id {
    my ($self, $tokens) = @_;
    $self->sth->{expr_id}->execute(@$tokens);
    return $self->sth->{expr_id}->fetchrow_array();
}

# return token id if the token exists
sub _token_id {
    my ($self, $token) = @_;

    $self->sth->{token_id}->execute($token);
    my $token_id = $self->sth->{token_id}->fetchrow_array();
    return if !defined $token_id;
    return $token_id;
}

# add token and/or return its id
sub _token_id_add {
    my ($self, $token) = @_;
    my $token_id;

    $self->sth->{token_id}->execute($token);
    $token_id = $self->sth->{token_id}->fetchrow_array();

    if (!defined $token_id) {
        $token_id = $self->_add_token($token);
    }

    return $token_id;
}

# add a new token and return its id
sub _add_token {
    my ($self, $token) = @_;
    $self->sth->{add_token}->execute($token);
    $self->sth->{last_token_rowid}->execute();
    return $self->sth->{last_token_rowid}->fetchrow_array;
}

# return a random expression containing the given token
sub _random_expr {
    my ($self, $token_id) = @_;
    my $dbh = $self->dbh;

    my $return;

    if (!defined $token_id) {
        $self->sth->{"random_expr"}->execute();
        $return = @{ $self->sth->{"random_expr"}->fetchall_arrayref() }[0];
    }
    else {
        # try the positions in a random order
        for my $pos (shuffle 0 .. $self->order-1) {
            my $column = "token${pos}_id";

            # get a random expression which includes the token at this position
            $self->sth->{"expr_by_$column"}->execute($token_id);
            $return = @{ $self->sth->{"expr_by_$column"}->fetchall_arrayref() }[0];
            last if defined $return;
        }
    }

    # return the expression id first, then the token ids
    return $return->[-1], @{ $return }[0..$#{$return}-1];
}

sub _pos_token {
    my ($self, $pos, $expr_id, $key_tokens) = @_;
    my $dbh = $self->dbh;

    $self->sth->{"${pos}_token_get"}->execute($expr_id);
    my $pos_tokens = $self->sth->{"${pos}_token_get"}->fetchall_hashref('token_id');

    if (defined $key_tokens) {
        for my $i (0 .. $#{ $key_tokens }) {
            next if !exists $pos_tokens->{ @$key_tokens[$i] };
            return splice @$key_tokens, $i, 1;
        }
    }

    my @novel_tokens;
    for my $token (keys %$pos_tokens) {
        push @novel_tokens, ($token) x $pos_tokens->{$token}{count};
    }
    return @novel_tokens[rand @novel_tokens];
}

sub save {
    my ($self) = @_;
    # no op
    return;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Mixin::DBD - A mixin class for L<Hailo> DBD
L<storage|Hailo::Role::Storage> backends

=head1 METHODS

The following methods must to be implemented by subclasses:

=head2 C<_exists_db>

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

__DATA__
__[ table_info ]__
CREATE TABLE info (
    attribute [% SWITCH dbd %][% CASE 'mysql' %]TEXT NOT NULL,
                              [% CASE DEFAULT %]TEXT NOT NULL UNIQUE PRIMARY KEY,
                              [% END %]
    text [% IF dbd == 'SQLite' %] TEXT [% ELSE %] VARCHAR(255) [% END %] NOT NULL
);
__[ table_token ]__
CREATE TABLE token (
    id   [% SWITCH dbd %][% CASE 'Pg'    %]SERIAL UNIQUE,
                         [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT,
                         [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT,
                         [% END %]
    text [% IF dbd == 'mysql' %] VARCHAR(255) [% ELSE %] TEXT [% END %] NOT NULL
);
__[ table_expr ]__
CREATE TABLE expr (
[% FOREACH i IN orders %]
    token[% i %]_id INTEGER NOT NULL REFERENCES token (id),
[% END %]
    id        [% SWITCH dbd %][% CASE 'Pg'    %]SERIAL UNIQUE
                              [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT
                              [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT
                              [% END %]
);
__[ table_next_token ]__
CREATE TABLE next_token (
    id       [% SWITCH dbd %][% CASE 'Pg'    %]SERIAL UNIQUE,
                             [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT,
                             [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT,
                             [% END %]
    expr_id  INTEGER NOT NULL REFERENCES expr (id),
    token_id INTEGER NOT NULL REFERENCES token (id),
    count    INTEGER NOT NULL
);
__[ table_prev_token ]__
CREATE TABLE prev_token (
    id       [% SWITCH dbd %][% CASE 'Pg'    %]SERIAL UNIQUE,
                             [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT,
                             [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT,
                             [% END %]
    expr_id  INTEGER NOT NULL REFERENCES expr (id),
    token_id INTEGER NOT NULL REFERENCES token (id),
    count    INTEGER NOT NULL
);
__[ table_indexes ]__
CREATE INDEX token_text on token (text);
[% FOREACH i IN orders %]
CREATE INDEX expr_token[% i %]_id on expr (token[% i %]_id);
[% END %]
CREATE INDEX expr_token_ids on expr ([% columns %]);
CREATE INDEX next_token_expr_id ON next_token (expr_id);
CREATE INDEX prev_token_expr_id ON prev_token (expr_id);
CREATE INDEX next_token_token_id ON next_token (token_id);
__[ query_get_order ]__
SELECT text FROM info WHERE attribute = 'markov_order';
__[ query_set_order ]__
INSERT INTO info (attribute, text) VALUES ('markov_order', ?);
__[ query_expr_id ]__
SELECT id FROM expr WHERE
[% FOREACH i IN orders %]
    token[% i %]_id = ? AND
[% END %]
__[ query_expr_by_token(NUM)_id ]__
SELECT * FROM expr WHERE [% column %] = ?
  ORDER BY [% IF dbd == 'mysql' %] RAND() [% ELSE %] RANDOM() [% END %] LIMIT 1;
__[ query_random_expr ]__
SELECT * from expr
[% SWITCH dbd %]
[% CASE 'Pg'    %]WHERE id >= (random()*C+1)::int
[% CASE 'mysql' %]WHERE id >= (abs(rand()) % (SELECT max(id) FROM expr))
[% CASE DEFAULT %]WHERE id >= (abs(random()) % (SELECT max(id) FROM expr))
[% END %]
  LIMIT 1;
__[ query_token_id ]__
SELECT id FROM token WHERE text = ?;
__[ query_token_text ]__
SELECT text FROM token WHERE id = ?;
__[ query_add_token ]__
INSERT INTO token (text) VALUES (?)[% IF dbd == 'Pg' %] RETURNING id[% END %];
__[ query_last_expr_rowid ]_
SELECT id FROM expr ORDER BY id DESC LIMIT 1;
__[ query_last_token_rowid ]__
SELECT id FROM token ORDER BY id DESC LIMIT 1;
__[ query_(next_token|prev_token)_count ]__
SELECT count FROM [% table %] WHERE expr_id = ? AND token_id = ?;
__[ query_(next_token|prev_token)_inc ]__
UPDATE [% table %] SET count = ? WHERE expr_id = ? AND token_id = ?
__[ query_(next_token|prev_token)_add ]__
INSERT INTO [% table %] (expr_id, token_id, count) VALUES (?, ?, 1);
__[ query_(next_token|prev_token)_get ]__
SELECT token_id, count FROM [% table %] WHERE expr_id = ?;
__[ query_(add_expr) ]__
INSERT INTO expr ([% columns %]) VALUES ([% ids %])[% IF dbd == 'Pg' %] RETURNING id[% END %];
__[ query_token_count ]__
SELECT count FROM next_token WHERE token_id = ?;
