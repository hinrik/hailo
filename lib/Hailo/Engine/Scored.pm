package Hailo::Engine::Scored;

use 5.010;
use Any::Moose;
use List::Util qw<sum>;
use List::MoreUtils qw<any>;
use Time::HiRes qw<gettimeofday tv_interval>;

extends 'Hailo::Engine::Default';

after BUILD => sub {
    my ($self) = @_;
    my %args = $self->arguments;

    if (defined $args{iterations} && defined $args{interval}) {
        die __PACKAGE__.": You can only specify one of 'iterations' and 'interval'\n";
    }
    return;
};

sub reply {
    my $self   = shift;
    my $tokens = shift // [];

    # see if we recognize any of the input tokens
    my $token_cache = $self->_resolve_input_tokens($tokens);
    my @input_token_ids = keys %$token_cache;
    my @token_counts;

    # let's select potential pivot tokens from the input
    if (keys %$token_cache) {
        # we only want the ones with normal spacing (usually normal words)
        @token_counts = map {
            $token_cache->{$_}[0] == 0 ? [$_, $token_cache->{$_}[2]] : ()
        } keys %$token_cache;
    }

    my $token_probs = $self->_get_pivot_probabilites(\@token_counts);
    my @started = gettimeofday();
    my $iterations = 0;

    my $done;
    my %args = $self->arguments;
    if (!defined $args{iterations} && !defined $args{interval}) {
        # construct replies for half a second by default
        $args{interval} = 0.5;
    }

    if (defined $args{iterations}) {
        $done = sub {
            return 1 if $iterations == $args{iterations};
        };
    }
    else {
        $done = sub {
            my $elapsed = tv_interval(\@started, [gettimeofday]);
            return 1 if $elapsed >= $args{interval};
        };
    }

    my (%link_cache, %expr_cache, $best_score, $best_reply);
    while (1) {
        $iterations++;
        my $reply = $self->_generate_reply($token_probs, \%expr_cache);
        return if !defined $reply; # we don't know any expressions yet

        my $score = $self->_evaluate_reply(\@input_token_ids, $reply, \%link_cache);

        if (defined $best_reply && $self->_too_similar(\@input_token_ids, $reply)) {
            last if $done->();
            next;
        }

        if (!defined $best_score || $score > $best_score) {
            $best_score = $score;
            $best_reply = $reply;
        }

        last if $done->();
    }

    # translate token ids to token spacing/text
    my @output = map {
        $token_cache->{$_} // ($token_cache->{$_} = $self->_token_info($_))
    } @$best_reply;
    return \@output;
}

# Calculate the probability we wish to pick each token as the pivot.
# This uses -log2(p) as a method for inverting token probability,
# ensuring that our rarer tokens are picked more often.
sub _get_pivot_probabilites {
    my ($self, $token_counts) = @_;

    return [] if !@$token_counts;
    return [[$token_counts->[0], 1]] if @$token_counts == 1;

    # calculate the (non-normalized) probability we want each to occur
    my $count_sum = sum(map { $_->[1] } @$token_counts);
    my $p = [];
    my $p_sum = 0;
    for my $token_count (map { $_->[1] } @$token_counts) {
        my $token_p = -log(($token_count/$count_sum))/log(2);
        push @$p, $token_p;
        $p_sum += $token_p;
    }

    # normalize the probabilities
    my @probs = map {
        [$token_counts->[$_], $p->[$_] / $p_sum];
    } 0..$#{ $token_counts };

    return \@probs;
}

sub _generate_reply {
    my ($self, $token_probs, $expr_cache) = @_;

    my ($pivot_expr_id, @token_ids) = @_;
    if (@$token_probs) {
        my $pivot_token_id = $self->_choose_pivot($token_probs);
        ($pivot_expr_id, @token_ids) = $self->_random_expr($pivot_token_id);
    }
    else {
        ($pivot_expr_id, @token_ids) = $self->_random_expr();
        return if !defined $pivot_expr_id; # no expressions in the database
    }

    # construct the end of the reply
    $self->_construct_reply('next', $pivot_expr_id, \@token_ids, $expr_cache);

    # construct the beginning of the reply
    $self->_construct_reply('prev', $pivot_expr_id, \@token_ids, $expr_cache);

    return \@token_ids;
}

sub _evaluate_reply {
    my ($self, $input_token_ids, $reply_token_ids, $cache) = @_;
    my $order = $self->order;
    my $score = 0;

    for my $idx (0 .. $#{ $reply_token_ids } - $order) {
        my $next_token_id = $reply_token_ids->[$idx];

        if (any { $_ == $next_token_id } @$input_token_ids) {
            my @expr = @$reply_token_ids[$idx .. $idx+$order-1];
            my $key = join('_', @expr)."-$next_token_id";

            if (!defined $cache->{$key}) {
                $cache->{$key} = $self->_expr_token_probability('next', \@expr, $next_token_id);
            }
            if ($cache->{$key} > 0) {
                $score -= log($cache->{$key})/log(2);
            }
        }
    }

    for my $idx (0 .. $#{ $reply_token_ids } - $order) {
        my $prev_token_id = $reply_token_ids->[$idx];

        if (any { $_ == $prev_token_id } @$input_token_ids) {
            my @expr = @$reply_token_ids[$idx+1 .. $idx+$order];
            my $key = "$prev_token_id-".join('_', @expr);

            if (!defined $cache->{$key}) {
                $cache->{$key} = $self->_expr_token_probability('prev', \@expr, $prev_token_id);
            }
            if ($cache->{$key} > 0) {
                $score -= log($cache->{$key})/log(2);
            }
        }
    }

    # Prefer shorter replies. This behavior is present but not
    # documented in recent MegaHAL.
    my $score_divider = 1;
    if (@$reply_token_ids >= 8) {
        $score_divider = sqrt(@$reply_token_ids - 1);
    }
    elsif (@$reply_token_ids >= 16) {
        $score_divider = @$reply_token_ids;
    }

    $score = $score / $score_divider;
    return $score;
}

sub _expr_token_probability {
    my ($self, $pos, $expr, $token_id) = @_;
    my $order = $self->order;

    my $expr_id = $self->_expr_id_add($expr);

    $self->{"_sth_${pos}_token_count"}->execute($expr_id, $token_id);
    my $expr2token = $self->{"_sth_${pos}_token_count"}->fetchrow_array();
    return 0 if !$expr2token;

    $self->{"_sth_${pos}_token_links"}->execute($expr_id);
    my $expr2all = $self->{"_sth_${pos}_token_links"}->fetchrow_array();
    return $expr2token / $expr2all;
}

sub _choose_pivot {
    my ($self, $token_probs) = @_;

    my $random = rand;
    my $p = 0;
    for my $token (@$token_probs) {
        $p += $token->[1];
        return $token->[0][0] if $p > $random;
    }

    return;
}

sub _too_similar {
    my ($self, $input_token_ids, $reply_token_ids) = @_;

    my %input_token_ids = map { +$_ => 1 } @$input_token_ids;

    for my $reply_token_id (@$reply_token_ids) {
        return if !$input_token_ids{$reply_token_id};
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

=encoding utf8

=head1 NAME

Hailo::Engine::Scored - MegaHAL-style reply scoring for L<Hailo|Hailo>

=head1 DESCRIPTION

This backend implements the logic of replying to and learning from
input using the resources given to the L<engine
roles|Hailo::Role::Engine>. It is inherits from
L<Hailo::Engine::Default|Hailo::Engine::Default> and only overrides its
C<reply> method.

It generates multiple replies and applies a scoring algorithm to them, then
returns the best one, similar to MegaHAL.

=head1 ATTRIBUTES

=head2 C<engine_args>

This is a hash reference which can have the following keys:

=head3 C<iterations>

The number of replies to generate before returning the best one.

=head3 C<interval>

The time (in seconds) to spend on generating replies before returning the
best one.

You can not specify both C<iterations> and C<interval> at the same time. If
neither is specified, a default C<interval> of 0.5 seconds will be used.

=head1 AUTHORS

Hinrik E<Ouml>rn SigurE<eth>sson, hinrik.sig@gmail.com

This module was based on code from Peter Teichman's Cobe project.

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Hinrik E<Ouml>rn SigurE<eth>sson and
E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
