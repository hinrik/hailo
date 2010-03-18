package Hailo::Storage::Schema;

use 5.010;
use strict;

## Soup to spawn the database itself / create statement handles
sub deploy {
    my ($self, $dbd, $dbh, $order) = @_;
    my @orders = (0 .. $order-1);

    my $int_primary_key = "INTEGER PRIMARY KEY AUTOINCREMENT";
    $int_primary_key    = "INTEGER PRIMARY KEY AUTO_INCREMENT" if $dbd eq "mysql";
    $int_primary_key    = "SERIAL UNIQUE" if $dbd eq "Pg";

    my $text = 'TEXT';
    $text    = 'VARCHAR(255)' if $dbd eq 'mysql';

    my $text_primary = 'TEXT NOT NULL PRIMARY KEY';
    $text_primary    = 'TEXT NOT NULL' if $dbd eq 'mysql';

    my @tables;

    push @tables => <<"TABLE";
CREATE TABLE info (
    attribute $text_primary,
    text      TEXT NOT NULL
);
TABLE

    push @tables => <<"TABLE";
CREATE TABLE token (
    id      $int_primary_key,
    spacing INTEGER NOT NULL,
    text    $ text NOT NULL,
    count   INTEGER NOT NULL
);
TABLE

    my $token_n = join ",\n    ", map { "token${_}_id INTEGER NOT NULL REFERENCES token (id)" } @orders;
    push @tables => <<"TABLE";
CREATE TABLE expr (
    id  $int_primary_key,
    $token_n
);
TABLE

    push @tables => <<"TABLE";
CREATE TABLE next_token (
    id       $int_primary_key,
    expr_id  INTEGER NOT NULL REFERENCES expr (id),
    token_id INTEGER NOT NULL REFERENCES token (id),
    count    INTEGER NOT NULL
);
TABLE

    push @tables => <<"TABLE";
CREATE TABLE prev_token (
    id       $int_primary_key,
    expr_id  INTEGER NOT NULL REFERENCES expr (id),
    token_id INTEGER NOT NULL REFERENCES token (id),
    count    INTEGER NOT NULL
);
TABLE

    for my $i (@orders) {
        push @tables => "CREATE INDEX expr_token${i}_id on expr (token${i}_id);"
    }

    my $columns = join(', ', map { "token${_}_id" } @orders);
    push @tables => "CREATE INDEX expr_token_ids on expr ($columns);";
    
    push @tables => 'CREATE INDEX token_text on token (text);';
    push @tables => 'CREATE INDEX next_token_expr_id ON next_token (expr_id);';
    push @tables => 'CREATE INDEX prev_token_expr_id ON prev_token (expr_id);';


    for (@tables) {
        $dbh->do($_);
    }

    return;
}

# create statement handle objects
sub sth {
    my ($self, $dbd, $dbh, $order)  = @_;
    my @orders  = (0 .. $order-1);
    my @columns = map { "token${_}_id" } 0 .. $order-1;
    my $columns = join(', ', @columns);
    my @ids     = join(', ', ('?') x @columns);
    my $ids     = join(', ', @ids);

    my $q_rand = 'RANDOM()';
    $q_rand    = 'RAND()' if $dbd eq 'mysql';

    my $q_rand_id = "(abs($q_rand) % (SELECT max(id) FROM expr))";
    $q_rand_id    = "(random()*id+1)::int" if $dbd eq 'Pg';

    my %state = (
        set_order        => qq[INSERT INTO info (attribute, text) VALUES ('markov_order', ?);],

        random_expr      => qq[SELECT * FROM expr WHERE id >= $q_rand_id LIMIT 1;],
        token_id         => qq[SELECT id FROM token WHERE spacing = ? AND text = ?;],
        token_info       => qq[SELECT spacing, text FROM token WHERE id = ?;],
        token_similar    => qq[SELECT id, spacing FROM token WHERE text = ? ORDER BY $q_rand LIMIT 1;] ,
        add_token        => qq[INSERT INTO token (spacing, text, count) VALUES (?, ?, 0)],
        inc_token_count  => qq[UPDATE token SET count = count + 1 WHERE id = ?],

        # ->stats()
        expr_total       => qq[SELECT COUNT(*) FROM expr;],
        token_total      => qq[SELECT COUNT(*) FROM token;],
        prev_total       => qq[SELECT COUNT(*) FROM prev_token;],
        next_total       => qq[SELECT COUNT(*) FROM next_token;],

        # Defaults, overriden in SQLite
        last_expr_rowid  => qq[SELECT id FROM expr ORDER BY id DESC LIMIT 1;],
        last_token_rowid => qq[SELECT id FROM token ORDER BY id DESC LIMIT 1;],

        next_token_count => qq[SELECT count FROM next_token WHERE expr_id = ? AND token_id = ?;],
        prev_token_count => qq[SELECT count FROM prev_token WHERE expr_id = ? AND token_id = ?;],
        next_token_inc   => qq[UPDATE next_token SET count = count + 1 WHERE expr_id = ? AND token_id = ?],
        prev_token_inc   => qq[UPDATE prev_token SET count = count + 1 WHERE expr_id = ? AND token_id = ?],
        next_token_add   => qq[INSERT INTO next_token (expr_id, token_id, count) VALUES (?, ?, 1);],
        prev_token_add   => qq[INSERT INTO prev_token (expr_id, token_id, count) VALUES (?, ?, 1);],
        next_token_get   => qq[SELECT token_id, count FROM next_token WHERE expr_id = ?;],
        prev_token_get   => qq[SELECT token_id, count FROM prev_token WHERE expr_id = ?;],

        token_count      => qq[SELECT count FROM token WHERE id = ?;],

        add_expr         => qq[INSERT INTO expr ($columns) VALUES ($ids)],
        expr_id          => qq[SELECT id FROM expr WHERE ] . join(' AND ', map { "token${_}_id = ?" } @orders),
    );

    for (@orders) {
        $state{"expr_by_token${_}_id"} = qq[SELECT * FROM expr WHERE token${_}_id = ? ORDER BY $q_rand LIMIT 1;];
    }

    # DBD specific queries / optimizations / munging
    given ($dbd) {
        when ('SQLite') {
            # Optimize these for SQLite
            $state{expr_total}       = qq[SELECT seq FROM sqlite_sequence WHERE name = 'expr';];
            $state{token_total}      = qq[SELECT seq FROM sqlite_sequence WHERE name = 'token';];
            $state{prev_total}       = qq[SELECT seq FROM sqlite_sequence WHERE name = 'prev_token';];
            $state{next_total}       = qq[SELECT seq FROM sqlite_sequence WHERE name = 'next_token';];
        }
        when ('Pg') {
            $state{exists_db} = qq[SELECT count(*) FROM information_schema.columns WHERE table_name ='info';];
        }
        when ('mysql') {
            $state{exists_db} = qq[SHOW TABLES;];
        }
    }

    # Sort to make error output easier to read if this fails. The
    # order doesn't matter.
    my @queries = sort keys %state;
    my %sth = map { $_ => $dbh->prepare($state{$_}) } @queries;

    return \%sth;
}

1;

=head1 NAME

Hailo::Storage::Schema - Deploy the database schema Hailo uses

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
