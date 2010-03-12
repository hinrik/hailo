package Hailo::Storage::DBD;
use 5.010;
use Any::Moose;
use Any::Moose 'X::Types::'.any_moose() => [qw<ArrayRef HashRef Int Str Bool>];
BEGIN {
    return unless Any::Moose::moose_is_preferred();
    require MooseX::StrictConstructor;
    MooseX::StrictConstructor->import;
}
use DBI;
use List::Util qw<first shuffle>;
use List::MoreUtils qw<uniq>;
use Data::Section qw(-setup);
use Template;
use namespace::clean -except => [ qw(meta
                                     section_data
                                     section_data_names
                                     merged_section_data
                                     merged_section_data_names) ];

has dbd => (
    isa           => Str,
    is            => 'ro',
    lazy_build    => 1,
    documentation => "The DBD::* driver we're using",
);

# Override me
sub _build_dbd { die }

has dbd_options => (
    isa           => HashRef,
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
    isa           => ArrayRef,
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
    isa           => Bool,
    is            => 'rw',
    default       => 0,
    documentation => 'Have we done setup work to get this database going?',
);

has sth => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    documentation => 'A HashRef of prepared DBI statement handles',
);

# our statement handlers
sub _build_sth {
    my ($self) = @_;
    my ($sections, $prefix) = $self->_sth_sections_static();
    return $self->_prepare_sth($sections, $prefix);
}

has _boundary_token_id => (
    isa => Int,
    is  => 'rw',
);

# create statement handle objects
sub _prepare_sth {
    my ($self, $sections, $prefix) = @_;

    my %state;
    while (my ($name, $options) = each %$sections) {
        my $section = $options->{section} // $name;
        my %options = %{ $options->{options} // {} };
        my $template = $self->section_data("$prefix$section");
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

    $state{$_} = $self->dbh->prepare($state{$_}) for keys %state;
    return \%state;
}

# return SQL statements which are not dependent on the Markov order
sub _sth_sections_static {
    my ($self) = @_;
    my %sections;
    my $prefix = 'static_query_';

    # () sections are magical
    my @plain_sections = grep { /^$prefix/ and not /\(.*?\)/ } $self->section_data_names;
    s[^$prefix][] for @plain_sections;

    $sections{$_} = undef for @plain_sections;

    for my $np (qw(next_token prev_token)) {
        for my $ciag (qw(count inc add get)) {
            $sections{$np . '_' . $ciag} = {
                section => "(next_token|prev_token)_$ciag",
                options => { table => $np },
            };
        }
    }

    return \%sections, $prefix;;
}

# return SQL statements which are dependent on the Markov order
sub _sth_sections_dynamic {
    my ($self) = @_;
    my %sections;
    my $prefix = 'dynamic_query_';

    # () sections are magical
    my @plain_sections = grep { /^$prefix/ and not /\(.*?\)/ } $self->section_data_names;
    s[^$prefix][] for @plain_sections;

    $sections{$_} = undef for @plain_sections;

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

    return \%sections, $prefix;
}

# bootstrap the database
sub _engage {
    my ($self) = @_;

    if ($self->_exists_db) {
        $self->sth->{get_order}->execute();
        my $order = $self->sth->{get_order}->fetchrow_array();
        $self->order($order);

        $self->sth->{token_id}->execute(0, '');
        my $id = $self->sth->{token_id}->fetchrow_array;
        $self->_boundary_token_id($id);
    }
    else {
        $self->_create_db();

        my $order = $self->order;
        $self->sth->{set_order}->execute($order);

        $self->sth->{add_token}->execute(0, '');
        $self->sth->{last_token_rowid}->execute();
        my $id = $self->sth->{last_token_rowid}->fetchrow_array();
        $self->_boundary_token_id($id);
    }

    # prepare SQL statements which depend on the Markov order
    my ($sections, $prefix) = $self->_sth_sections_dynamic();
    my $sth = $self->_prepare_sth($sections, $prefix);
    while (my ($query, $st) = each %$sth) {
        $self->sth->{$query} = $st;
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

# return some statistics
sub totals {
    my ($self) = @_;
    $self->_engage() if !$self->_engaged;

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

## no critic (Subroutines::ProhibitExcessComplexity)
sub make_reply {
    my $self = shift;
    my $tokens = shift // [];
    $self->_engage() if !$self->_engaged;
    my $order = $self->order;

    # we will favor these tokens when making the reply
    my @key_tokens = @$tokens;

    # shuffle the tokens and discard half of them
    @key_tokens = do {
        my $i = 0;
        grep { $i++ % 2 == 0 } shuffle(@key_tokens);
    };

    my (@key_ids, %token_cache);
    for my $token_info (@key_tokens) {
        my $text = $token_info->[1];
        my $info = $self->_token_similar($text);
        next if !defined $info;
        my ($id, $spacing) = @$info;
        next if !defined $id;
        push @key_ids, $id;
        next if exists $token_cache{$id};
        $token_cache{$id} = [$spacing, $text];
    }

    # sort the rest by rareness
    @key_ids = $self->_find_rare_tokens(\@key_ids, 2);

    # get the middle expression
    my $seed_token_id = shift @key_ids;
    my ($orig_expr_id, @token_ids) = $self->_random_expr($seed_token_id);
    return if !defined $orig_expr_id; # we don't know any expressions yet

    # remove key tokens we're already using
    @key_ids = grep { my $used = $_; !first { $_ == $used } @token_ids } @key_ids;

    my $repeat_limit = $self->repeat_limit;
    my $expr_id = $orig_expr_id;

    # construct the end of the reply
    my $i = 0;
    while (1) {
        if (($i % $order) == 0 and
            (($i >= $repeat_limit * 3) ||
             ($i >= $repeat_limit and uniq(@token_ids) <= $order))) {
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
            (($i >= $repeat_limit * 3) ||
             ($i >= $repeat_limit and uniq(@token_ids) <= $order))) {
            last;
        }
        my $prev_id = $self->_pos_token('prev', $expr_id, \@key_ids);
        last if $prev_id eq $self->_boundary_token_id;
        unshift @token_ids, $prev_id;
        $expr_id = $self->_expr_id([@token_ids[0..$order-1]]);
    } continue {
        $i++;
    }

    # translate token ids to token spacing/text
    my @reply;
    for my $id (@token_ids) {
        if (!exists $token_cache{$id}) {
            $self->sth->{token_info}->execute($id);
            $token_cache{$id} = [$self->sth->{token_info}->fetchrow_array];
        }
        push @reply, $token_cache{$id};
    }
    return \@reply;
}

sub learn_tokens {
    my ($self, $tokens) = @_;
    my $order = $self->order;
    my %token_cache;

    for my $token (@$tokens) {
        my $key = join '', @$token;
        next if exists $token_cache{$key};
        $token_cache{$key} = $self->_token_id_add($token);
    }

    # process every expression of length $order
    for my $i (0 .. @$tokens - $order) {
        my @expr = map { $token_cache{ join('', @{ $tokens->[$_] }) } } $i .. $i+$order-1;
        my $expr_id = $self->_expr_id(\@expr);

        if (!defined $expr_id) {
            $expr_id = $self->_add_expr(\@expr);
            $self->sth->{inc_token_count}->execute($_) for uniq(@expr);
        }

        # add link to next token for this expression, if any
        if ($i < @$tokens - $order) {
            my $next_id = $token_cache{ join('', @{ $tokens->[$i+$order] }) };
            $self->_inc_link('next_token', $expr_id, $next_id);
        }

        # add link to previous token for this expression, if any
        if ($i > 0) {
            my $prev_id = $token_cache{ join('', @{ $tokens->[$i-1] }) };
            $self->_inc_link('prev_token', $expr_id, $prev_id);
        }

        # add links to boundary token if appropriate
        my $b = $self->_boundary_token_id;
        $self->_inc_link('prev_token', $expr_id, $b) if $i == 0;
        $self->_inc_link('next_token', $expr_id, $b) if $i == @$tokens-$order;
    }

    return;
}

# sort token ids based on how rare they are
sub _find_rare_tokens {
    my ($self, $token_ids, $min) = @_;
    return if !@$token_ids;

    my %links;
    for my $id (@$token_ids) {
        next if exists $links{$id};
        $self->sth->{token_count}->execute($id);
        $links{$id} = $self->sth->{token_count}->fetchrow_array;
    }

    # remove tokens which are too rare
    my @ids = grep { $links{$_} >= $min } @$token_ids;

    @ids = sort { $links{$a} <=> $links{$b} } @ids;

    return @ids;
}

# increase the link weight between an expression and a token
sub _inc_link {
    my ($self, $type, $expr_id, $token_id) = @_;

    $self->sth->{"${type}_count"}->execute($expr_id, $token_id);
    my $count = $self->sth->{"${type}_count"}->fetchrow_array;

    if (defined $count) {
        $self->sth->{"${type}_inc"}->execute($expr_id, $token_id);
    }
    else {
        $self->sth->{"${type}_add"}->execute($expr_id, $token_id);
    }

    return;
}

# add new expression to the database
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
    my ($self, $token_info) = @_;

    $self->sth->{token_id}->execute(@$token_info);
    my $token_id = $self->sth->{token_id}->fetchrow_array();

    return if !defined $token_id;
    return $token_id;
}

# get token id (adding the token if it doesn't exist)
sub _token_id_add {
    my ($self, $token_info) = @_;

    my $token_id = $self->_token_id($token_info);
    $token_id = $self->_add_token($token_info) if !defined $token_id;
    return $token_id;
}

# return all tokens (regardless of spacing) that consist of this text
sub _token_similar {
    my ($self, $token_text) = @_;
    $self->sth->{token_similar}->execute($token_text);
    return $self->sth->{token_similar}->fetchrow_arrayref;
}

# add a new token and return its id
sub _add_token {
    my ($self, $token_info) = @_;
    $self->sth->{add_token}->execute(@$token_info);
    $self->sth->{last_token_rowid}->execute();
    return $self->sth->{last_token_rowid}->fetchrow_array;
}

# return a random expression containing the given token
sub _random_expr {
    my ($self, $token_id) = @_;
    my $dbh = $self->dbh;

    my $expr;

    if (!defined $token_id) {
        $self->sth->{random_expr}->execute();
        $expr = $self->sth->{random_expr}->fetchrow_arrayref();
    }
    else {
        # try the positions in a random order
        for my $pos (shuffle 0 .. $self->order-1) {
            my $column = "token${pos}_id";

            # get a random expression which includes the token at this position
            $self->sth->{"expr_by_$column"}->execute($token_id);
            $expr = $self->sth->{"expr_by_$column"}->fetchrow_arrayref();
            last if defined $expr;
        }
    }

    return if !defined $expr;
    return @$expr;
}

# return a new next/previous token
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
    return $novel_tokens[rand @novel_tokens];
}

sub save {
    my ($self) = @_;
    # no op
    return;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::DBD - A base class for L<Hailo> DBD
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
    attribute [% SWITCH dbd %]
                  [% CASE 'mysql' %]TEXT NOT NULL,
                  [% CASE DEFAULT %]TEXT NOT NULL PRIMARY KEY,
              [% END %]
    text      TEXT NOT NULL
);
__[ table_token ]__
CREATE TABLE token (
    id   [% SWITCH dbd %]
            [% CASE 'Pg'    %]SERIAL UNIQUE,
            [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT,
            [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT,
         [% END %]
    spacing INTEGER NOT NULL,
    text [% IF dbd == 'mysql' %] VARCHAR(255) [% ELSE %] TEXT [% END %] NOT NULL,
    count INTEGER NOT NULL
);
__[ table_expr ]__
CREATE TABLE expr (
    id  [% SWITCH dbd %]
            [% CASE 'Pg'    %]SERIAL UNIQUE
            [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT
            [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT
        [% END %],
[% FOREACH i IN orders %]
    token[% i %]_id INTEGER NOT NULL REFERENCES token (id)[% UNLESS loop.last %],[% END %]
[% END %]
);
__[ table_next_token ]__
CREATE TABLE next_token (
    id       [% SWITCH dbd %]
                 [% CASE 'Pg'    %]SERIAL UNIQUE,
                 [% CASE 'mysql' %]INTEGER PRIMARY KEY AUTO_INCREMENT,
                 [% CASE DEFAULT %]INTEGER PRIMARY KEY AUTOINCREMENT,
             [% END %]
    expr_id  INTEGER NOT NULL REFERENCES expr (id),
    token_id INTEGER NOT NULL REFERENCES token (id),
    count    INTEGER NOT NULL
);
__[ table_prev_token ]__
CREATE TABLE prev_token (
    id       [% SWITCH dbd %]
                 [% CASE 'Pg'    %]SERIAL UNIQUE,
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
__[ static_query_get_order ]__
SELECT text FROM info WHERE attribute = 'markov_order';
__[ static_query_set_order ]__
INSERT INTO info (attribute, text) VALUES ('markov_order', ?);
__[ static_query_token_total ]__
SELECT COUNT(id) FROM token;
__[ static_query_expr_total ]__
SELECT COUNT(id) FROM expr;
__[ static_query_prev_total ]__
SELECT COUNT(id) FROM prev_token;
__[ static_query_next_total ]__
SELECT COUNT(id) FROM next_token;
__[ static_query_random_expr ]__
SELECT * from expr
[% SWITCH dbd %]
    [% CASE 'Pg'    %]WHERE id >= (random()*id+1)::int
    [% CASE 'mysql' %]WHERE id >= (abs(rand()) % (SELECT max(id) FROM expr))
    [% CASE DEFAULT %]WHERE id >= (abs(random()) % (SELECT max(id) FROM expr))
[% END %]
  LIMIT 1;
__[ static_query_token_id ]__
SELECT id FROM token WHERE spacing = ? AND text = ?;
__[ static_query_token_info ]__
SELECT spacing, text FROM token WHERE id = ?;
__[ static_query_token_similar ]__
SELECT id, spacing FROM token WHERE text = ?
[% SWITCH dbd %]
    [% CASE 'mysql'  %]ORDER BY RAND()   LIMIT 1;
    [% CASE DEFAULT  %]ORDER BY RANDOM() LIMIT 1;
[% END %]
__[ static_query_add_token ]__
INSERT INTO token (spacing, text, count) VALUES (?, ?, 0)
[% IF dbd == 'Pg' %] RETURNING id[% END %];
__[ static_query_inc_token_count ]__
UPDATE token SET count = count + 1 WHERE id = ?;
__[ static_query_last_expr_rowid ]_
SELECT id FROM expr ORDER BY id DESC LIMIT 1;
__[ static_query_last_token_rowid ]__
SELECT id FROM token ORDER BY id DESC LIMIT 1;
__[ static_query_(next_token|prev_token)_count ]__
SELECT count FROM [% table %] WHERE expr_id = ? AND token_id = ?;
__[ static_query_(next_token|prev_token)_inc ]__
UPDATE [% table %] SET count = count + 1 WHERE expr_id = ? AND token_id = ?
__[ static_query_(next_token|prev_token)_add ]__
INSERT INTO [% table %] (expr_id, token_id, count) VALUES (?, ?, 1);
__[ static_query_(next_token|prev_token)_get ]__
SELECT token_id, count FROM [% table %] WHERE expr_id = ?;
__[ static_query_token_count ]__
SELECT count FROM token WHERE id = ?;
__[ dynamic_query_(add_expr) ]__
INSERT INTO expr ([% columns %]) VALUES ([% ids %])
[% IF dbd == 'Pg' %] RETURNING id[% END %];
__[ dynamic_query_expr_by_token(NUM)_id ]__
SELECT * FROM expr WHERE [% column %] = ?
[% SWITCH dbd %]
    [% CASE 'mysql'  %]ORDER BY RAND()   LIMIT 1;
    [% CASE DEFAULT  %]ORDER BY RANDOM() LIMIT 1;
[% END %]
__[ dynamic_query_expr_id ]__
SELECT id FROM expr WHERE
[% FOREACH i IN orders %]
    token[% i %]_id = ? [% UNLESS loop.last %] AND [% END %]
[% END %]
