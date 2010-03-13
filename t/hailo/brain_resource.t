use strict;
use warnings;
use Test::More tests => 1;
use Hailo;

my $hailo = Hailo->new(
    brain => ':memory:',
);
$hailo->learn("brain_resource is an alias for brain");
ok($hailo->reply(), "brain_resource is an alias for brain");
