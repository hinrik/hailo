use strict;
use warnings;
use Test::More;
use File::Temp qw<tempdir tempfile>;
use File::Slurp qw<slurp>;
use Bot::Training;
use Hailo;

plan skip_all => "This test is known to fail on OpenBSD" if $^O eq 'openbsd';
plan tests => 6;

# Dir to store our brains
my $dir = tempdir( "hailo-test-storage-switch-tokenizer-XXXX", CLEANUP => 1, TMPDIR => 1 );

my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite', EXLOCK => 0 );

my $trainfile = Bot::Training->new->file("starcraft")->file;
my @train = split /\n/, slurp($trainfile);

{
    my $hailo = Hailo->new(
        brain => ':memory:',
    );
    is($hailo->tokenizer_class, "Words", "Default tokenizer_class = Words");
}

my $initial_tokenizer = "Chars";
{
    my $hailo = Hailo->new(
        brain  => $brain_file,
        tokenizer_class => $initial_tokenizer,
    );
    is($hailo->tokenizer_class, $initial_tokenizer, "tokenizer_class = $initial_tokenizer");
    $hailo->train(\@train);
    my ($tokens) = $hailo->stats;
    is($tokens, 62, "Hailo now knows about lots of tokens");

    my $tokenizer = get_meta($hailo, 'tokenizer_class');
    is($tokenizer, $initial_tokenizer, "The saved tokenizer is $initial_tokenizer");
}

subtest "Load from existing brain" => sub {
    plan tests => 7;

    ok(-f $brain_file, "$brain_file is still -f");
    my $hailo = Hailo->new(
        brain  => $brain_file,
    );
    ok($hailo, "Construct a new Hailo from an existing brain");
    is($hailo->tokenizer_class, "Words", "Standard order is still Words");
    my $reply = $hailo->reply();
    ok($reply, "Got reply $reply from Hailo");
    is($hailo->tokenizer_class, $initial_tokenizer, "Tokenizer has been loaded from the database");
    is($hailo->_storage->tokenizer_class, $initial_tokenizer, "Tokenizer has been propagated from the database -> storage");
    my ($tokens) = $hailo->stats;
    is($tokens, 62, "Hailo still knows about 62 tokens");
};

subtest "Load from an existing brain, die on explicit tokeziner" => sub {
    plan tests => 6;

    my $hailo = Hailo->new(
        brain  => $brain_file,
        tokenizer_class => "Words",
    );
    ok($hailo, "Construct a new Hailo from an existing brain");
    is($hailo->tokenizer_class, "Words", "Standard order is still Words");

    for (1..2)
    {
        local $@;
        eval { $hailo->reply() };
        like($@, qr/You've manually supplied a tokenizer class `Words'/, "Tried to reply after setting custom tokenizer_class Words");
    }

    ok($hailo->_storage->dbh->do(qq[DELETE FROM info WHERE attribute = 'tokenizer_class']), "Deleted tokenizer_class from database");

    my $reply = $hailo->reply();
    ok($reply, "Got reply $reply");
};

sub get_meta {
    my ($hailo, $k) = @_;
    my $sth = $hailo->_storage->dbh->prepare(qq[SELECT text FROM info WHERE attribute = ?;]);
    $sth->execute($k);
    my $data = $sth->fetchrow_array();
    return $data
}

