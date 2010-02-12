package Hailo::Storage::Mixin::Hash::Flat;
use 5.10.0;
use Moose;
use MooseX::StrictConstructor;
use namespace::clean -except => 'meta';

our $VERSION = '0.10';

extends 'Hailo::Storage::Mixin::Hash';

with 'Hailo::Role::Log';

sub _build__memory_area {
    # The hash we store all our data in
    my %memory;
    return \%memory;
}

sub _exists {
    my ($self, $k) = @_;
    my $mem = $self->_memory;

    # $self->meh->trace("Checking if '$k' exists");

    return exists $mem->{$k};
}

sub _set {
    my ($self, $k, $v) = @_;
    my $mem = $self->_memory;

    # $self->meh->trace("Setting '$k' = '$v'");

    return $mem->{$k} = $v;
}

sub _get {
    my ($self, $k) = @_;
    my $mem = $self->_memory;

    # $self->meh->trace("Getting '$k'");
    my $v = $mem->{$k};
    # $self->meh->trace("Value for '$k' is '$v'");
    return $v;
}

sub _increment {
    my ($self, $k) = @_;
    my $mem = $self->_memory;

    # $self->meh->trace("Incrementing $k");

    if (not exists $mem->{$k}) {
        $mem->{$k} = 1;
        return 0;
    } else {
        $mem->{$k} += 1;
        return $mem->{$k} - 1;
    }
}

sub _expr_exists {
    my ($self, $ehash) = @_;

    # $self->meh->trace("expr_exists: Checking if 'expr-$ehash' exists");
    return $self->_exists("expr-$ehash");
}

sub _expr_add_tokens {
    my ($self, $ehash, $tokens) = @_;

    my $count = $#{ $tokens };
    $self->_set("expr-$ehash", $count);
    $self->_set("expr-$ehash-$_", $tokens->[$_]) for 0 .. $count;

    return;
}

sub _token_push_ehash {
    my ($self, $token, $ehash) = @_;

    my $count = $self->_increment("token-$token");
    $self->_set("token-$token-$count", $ehash);

    return;
}

sub _pos_token_ehash_increment {
    my ($self, $pos_token, $ehash, $token) = @_;

    # XXX: Do we increment the count when the '' token gets added?
    my $count = $self->_increment("$pos_token-$ehash");
    $self->_set("$pos_token-$ehash", $count);
    $self->_set("$pos_token-$ehash-$count", $token);
    $self->_increment("$pos_token-$ehash-token-$token");

    return;
}

sub _token_exists {
    my ($self, $token) = @_;
    return 1 if $self->_exists("token-$token");
    return;
}

sub _random_expr {
    my ($self, $token) = @_;
    my $token_k = "token-$token";
    my $token_v = $self->_get($token_k);
    my $token_num = int rand $token_v;
    # $self->meh->trace("Got token num '$token_num' for k/v '$token_k'/'$token_v' ");
    my $ehash     = $self->_get("$token_k-$token_num");
    my @tokens    = map { $self->_get("expr-$ehash-$_") } 0 .. $self->_get("expr-$ehash");
    return @tokens;
}

sub _pos_token {
    my ($self, $pos, $tokens, $key_tokens) = @_;

    my $ehash = $self->_hash_tokens($tokens);
    my $pos_tokens = $self->_x_tokens("${pos}_token", $ehash);

    if (defined $key_tokens) {
        for my $i (0 .. $#{ $key_tokens }) {
            next if !exists $pos_tokens->{ @$key_tokens[$i] };
            return splice @$key_tokens, $i, 1;
        }
    }

    my @novel_tokens;
    for my $token (keys %$pos_tokens) {
        push @novel_tokens, ($token) x $pos_tokens->{$token};
    }
    return @novel_tokens[rand @novel_tokens];
}

sub _x_tokens {
    my ($self, $pos_token, $ehash) = @_;
    my $key = "$pos_token-$ehash";

    return unless $self->_exists($key);

    my $count = $self->_get($key);

    my %tokens = (
        map {
            my $k = $self->_get("$key-$_");
            $k => $self->_get("$key-token-$k");
        } 0 .. $count,
    );

    return \%tokens;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Storage::Mixin::Hash::Flat - A mixin class for
L<storage|Hailo::Role::Storage> classes using a flat C<HashRef>

=head1 DESCRIPTION

This skeleton mixin backend maintains information in a flat Perl
C<HashRef>. It's meant to be subclassed for use by key-value stores
which can't handle keys that are C<HashRef> or C<ArrayRef>.

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
