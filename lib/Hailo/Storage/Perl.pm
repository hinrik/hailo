package Hailo::Storage::Perl;

use 5.010;
use Moose;
use MooseX::Types::Moose qw<HashRef Int Str>;
use Storable;
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

has file => (
    isa => Str,
    is  => 'ro',
);

has order => (
    isa     => Int,
    is      => 'ro',
    default => sub { shift->memory->{order} },
);

has _memory => (
    isa        => HashRef,
    is         => 'ro',
    lazy_build => 1,
    init_arg   => undef,
);

with 'Hailo::Storage';

sub _build__memory {
    my ($self) = @_;

    if (defined $self->file && -s $self->file) {
        return retrieve($self->file);
    }
    else {
        # TODO: these data structures aren't very normalized, so they take up
        # much more memory than necessary
        return {
            token      => { }, # $token => [$id, \@ehash_of_exprs_that_contain_it]
            expr       => { }, # $ehash => [$id, \@tokens_it_contains]
            next_token => { }, # $ehash => [$id, \%tokens_that_can_follow_this_expr]
            prev_token => { }, # $ehash => [$id, \%tokens_that_can_precede_this_expr]
            order      => $self->order,
        };
    }
}

{
    my %id = (
        token      => 0,
        expr       => 0,
        next_token => 0,
        prev_token => 0,
    );

    sub _next_id {
        my ($type) = @_;
        return $id{$type}++;
    }
}

sub add_expr {
    my ($self, %args) = @_;
    my $mem = $self->_memory;

    my $ehash = $self->_hash_tokens($args{tokens});

    if (!exists $mem->{expr}{$ehash}) {
        $mem->{expr}{$ehash} = [_next_id('expr'), $args{tokens}];

        for my $token (@{ $args{tokens} }) {
            my $id = _next_id('token');
            $mem->{token}{$token} = [$id, [ ]] if !exists $mem->{token}{$token};
            push @{ $mem->{token}{$token}[1] }, $ehash;
        }
    }

    for my $pos_token (qw(next_token prev_token)) {
        if (defined $args{$pos_token}) {
            my $id = _next_id($pos_token);
            if (!exists $mem->{$pos_token}{$ehash}) {
                $mem->{$pos_token}{$ehash} = [$id, { }];
            }
            $mem->{$pos_token}{$ehash}[1]{ $args{$pos_token} }++;
        }
    }
    return;
}

sub token_exists {
    my ($self, $token) = @_;
    return 1 if exists $self->_memory->{token}{$token};
    return;
}

sub random_expr {
    my ($self, $token) = @_;
    my @ehash = @{ $self->_memory->{token}{$token}[1] };
    return @{ @{ $self->_memory->{expr}{ $ehash[rand @ehash] } }[1] };
}

sub next_tokens {
    my ($self, $expr) = @_;
    my $ehash = $self->_hash_tokens($expr);
    return $self->_memory->{next_token}{ $ehash }[1];
}

sub prev_tokens {
    my ($self, $expr) = @_;
    my $ehash = $self->_hash_tokens($expr);
    return $self->_memory->{prev_token}{ $ehash }[1];
}

# concatenate contents of an expression for unique identification
sub _hash_tokens {
    my ($self, $tokens) = @_;
    my $ehash = join $self->token_separator, @$tokens;
    return $ehash;
}

sub save {
    my ($self) = @_;
    #store($self->_memory, $self->file);
    $self->_dump_sql();
    return;
}

sub start_training {
    my ($self) = @_;
    return;
}

sub stop_training {
    my ($self) = @_;
    return;
}

sub _sql_escape {
    my @strings = @_;

    s/'/''/g for @strings;
    return $strings[0] if @strings == 1;
    return @strings;
}

sub _dump_sql {
    my ($self) = @_;
    my $mem = $self->_memory;
    open my $fh, '>:encoding(utf8)', $self->file or die "Can't open ".$self->file.": $!\n";

    say $fh "PRAGMA synchronous=OFF;";
    say $fh "BEGIN TRANSACTION;";

    my $token_count;
    while (my ($token, $entry) = each %{ $mem->{token} }) {
        say "token: ", ++$token_count;
        my $esc_token = _sql_escape($token);
        say $fh "INSERT INTO token VALUES ($entry->[0], '$esc_token');";
    }

    my $expr_count;
    while (my ($expr, $entry) = each %{ $mem->{expr} }) {
        say "expr: ",++$expr_count;
        my $expr_text = join("\t", _sql_escape(@{ $entry->[1] }));
        my @token_ids = map { $mem->{token}{$_}[0] } @{ $entry->[1] };
        say $fh "INSERT INTO expr VALUES ($entry->[0], '$expr_text', ".join(', ', @token_ids).');';
    }
    for my $pos_token (qw(next_token prev_token)) {
        my $pos_token_count;
        my $id = 0;
        while (my ($ehash, $entry) = each %{ $mem->{$pos_token} }) {
            say "$pos_token: ",++$pos_token_count;
            my $expr_id = $mem->{expr}{$ehash}[0];
            while (my ($token, $count) = each %{ $entry->[1] }) {
                $id++;
                my $token_id = $mem->{token}{$token}[0];
                say $fh "INSERT INTO $pos_token VALUES ($id, $expr_id, $token_id, $count);";
            }
        }
    }

    say $fh "COMMIT;";
}

__PACKAGE__->meta->make_immutable;

1;

=encoding utf8

=head1 NAME

Hailo::Storage::Perl - A storage backend for L<Hailo|Hailo> using Perl structures

=head1 DESCRIPTION

This backend maintains information in a Perl hash, with an option to
save to/load from a file with L<Storable|Storable>.

It is fast, but uses a lot of memory.

=head1 AUTHOR

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
