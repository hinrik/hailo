package Hailo::Role::Log;
use 5.010;
use MooseX::Role::Strict;
use Log::Log4perl;
use namespace::clean -except => 'meta';

our $VERSION = '0.13';

# Adapted from http://stackoverflow.com/questions/2232430/possible-to-get-log4perl-to-report-actually-line-number-of-log-event/2232473

my @methods = qw(
    log trace debug info warn error fatal
    is_trace is_debug is_info is_warn is_error is_fatal
    logexit logwarn error_warn logdie error_die
    logcarp logcluck logcroak logconfess
);

has 'meh' => (
    is         => 'ro',
    isa        => 'Log::Log4perl::Logger',
    traits     => [qw(NoGetopt)],
    lazy_build => 1,
    handles    => \@methods,
);

around $_ => sub {
    my $orig = shift;
    my $self = shift;

    # one level for this method itself
    # two levels for Class::MOP::Method::Wrapped (the "around" wrapper)
    # one level for Moose::Meta::Method::Delegation (the "handles" wrapper)
    $Log::Log4perl::caller_depth += 4;

    my $return = $self->$orig(@_);

    $Log::Log4perl::caller_depth -= 4;
    return $return;

} for @methods;

sub _build_meh
{
    my ($self) = @_;

    unless (Log::Log4perl::initialized()) {
        my $conf = do { local $/ = undef; <DATA> };
        Log::Log4perl->init(\$conf);
    }

    return Log::Log4perl->get_logger(ref $self)
}

1;

=encoding utf8

=head1 NAME

Hailo::Role::Log - A logging role for L<Hailo|Hailo> using L<Log::Log4perl>

=head1 AUTHOR

E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason <avar@cpan.org>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 E<AElig>var ArnfjE<ouml>rE<eth> Bjarmason.

This program is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__DATA__
log4perl.rootLogger = INFO, Console

log4perl.appender.Console        = Log::Log4perl::Appender::Screen
log4perl.appender.Console.utf8   = 1
log4perl.appender.Console.stderr = 1
log4perl.appender.Console.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Console.layout.ConversionPattern = %p [%c] [%M] %m%n
