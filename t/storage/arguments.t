use 5.10.0;
use strict;
use warnings;
use Test::More tests => 5;
use Hailo;

my $arguments = {
    dbname => 'hailo',
    host => 'localhost',
    port => '5432',
    options => '...',
    username => 'hailo',
    password => 'hailo'
};

my $hailo = Hailo->new(
    storage_class => "Pg",
    storage_args  => $arguments,
);

is_deeply(scalar $hailo->_storage_obj->arguments, $arguments, "Arguments were passed to Pg");

my $conn_line = $hailo->_storage_obj->dbi_options->[0];
while (my ($k, $v) = each %$arguments) {
    next if $k =~ /^(username|password)$/;
    like($conn_line, qr/$k=$v/, "connection line '$conn_line' has $k=$v");
}

