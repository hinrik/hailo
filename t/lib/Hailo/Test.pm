package Hailo::Test;
use 5.010;
use autodie;
use Any::Moose;
use Hailo;
use Test::More;
use File::Spec::Functions qw(catfile);
use File::Slurp qw(slurp);
use List::Util qw(shuffle min);
use File::Temp qw(tempfile tempdir);
use File::CountLines qw(count_lines);
use Hailo::Tokenizer::Words;
use namespace::clean -except => 'meta';

sub all_storages {
    return qw(DBD::SQLite DBD::Pg DBD::mysql);
}

sub simple_storages {
    return grep { /sqlite/i } all_storages();
}

sub all_tests {
    return qw(test_starcraft test_congress test_congress_unknown test_babble test_badger test_megahal);
}

sub exhaustive_tests {
    return (all_tests(), qw(test_timtoady));
}

has brief => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has in_memory => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
);

has exhaustive => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has tmpdir => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_tmpdir {
    my ($self) = @_;
    my $storage = $self->storage;

    $storage =~ s/[^A-Za-z0-9]/-/g;

    # Dir to store our brains
    my $dir = tempdir( "hailo-test-$storage-XXXXX", CLEANUP => 1, TMPDIR => 1 );

    return $dir;
}

has brain => (
    is => 'ro',
    isa => 'Str',
);

has tmpfile => (
    is => 'ro',
    lazy_build => 1,
);

sub _build_tmpfile {
    my ($self) = @_;

    # Dir to store our brains
    my $dir = $self->tmpdir;

    my ($fh, $filename) = tempfile( DIR => $dir, SUFFIX => '.trn' );
    $fh->autoflush(1);

    return [$fh, $filename];
}

has hailo => (
    is => 'ro',
    isa => "Hailo",
    lazy_build => 1,
);

sub _build_hailo {
    my ($self) = @_;
    my $storage = $self->storage;

    my %opts = $self->_connect_opts;
    my $hailo = Hailo->new(%opts);

    return $hailo;
}

sub get_brain {
    my ($self) = @_;
    my $storage = $self->storage;
    my $brainrs = $self->brain;

    given ($storage) {
        when (/mysql/) {
            my $name = $self->tmpfile->[1];
            $name =~ s[[^A-Za-z]][_]g;
            return $name;
        }
        default {
            return $self->brain // $self->tmpfile->[1];
        }
    }
}

sub spawn_storage {
    my ($self) = @_;
    my $storage = $self->storage;
    my $brainrs = $self->get_brain;
    my $ok = 1;

    my %classes = (
        Pg                => 'DBD::Pg',
        mysql             => 'DBD::mysql',
    );

    if (exists $classes{$storage}) {
        my $pkg = $classes{$storage};
        if (Any::Moose::moose_is_preferred()) {
            require Class::MOP;
            eval { Class::MOP::load_class($pkg) };
        } else {
            eval qq[require $pkg];
        }

        return if $@;
    }

    given ($storage) {
        when (/Pg/) {
            plan skip_all => "You must set TEST_POSTGRESQL= and have permission to createdb(1) to test PostgreSQL" unless $ENV{TEST_POSTGRESQL};

            # It doesn't use the file to store data obviously, it's just a convenient random token.
            if (system "createdb '$brainrs' >/dev/null 2>&1") {
                $ok = 0;
            } else {
                # Kill Pg notices
                $SIG{__WARN__} = sub { print STDERR @_ if $_[0] !~ m/NOTICE:\s*CREATE TABLE/; };
            }
        }
        when (/mysql/) {
            plan skip_all => "You must set TEST_MYSQL= and MYSQL_ROOT_PASSWORD= to test MySQL" unless $ENV{TEST_MYSQL} and $ENV{MYSQL_ROOT_PASSWORD};
            system qq[echo "CREATE DATABASE $brainrs;" | mysql -u root -p$ENV{MYSQL_ROOT_PASSWORD}] and die $!;
            system qq[echo "GRANT ALL ON $brainrs.* TO hailo\@localhost IDENTIFIED BY 'hailo';;" | mysql -u root -p$ENV{MYSQL_ROOT_PASSWORD}] and die $!;
            system qq[echo "FLUSH PRIVILEGES;" | mysql -u root -p$ENV{MYSQL_ROOT_PASSWORD}] and die $!;
            $self->{_created_mysql} = 1;
        }
    }

    return $ok;
}

sub unspawn_storage {
    my ($self) = @_;
    my $storage = $self->storage;
    my $brainrs = $self->get_brain;

    my $nuke_db = sub {
        $_->finish for values %{ $self->hailo->_storage->sth };
        $self->hailo->_storage->dbh->disconnect;
    };

    given ($storage) {
        when (/Pg/) {
            $nuke_db->();
            system "dropdb '$brainrs'";
        }
        when (/SQLite/) {
            $nuke_db->();
        }
        when (/mysql/) {
            if ($self->{_created_mysql}) {
                system qq[echo "DROP DATABASE $brainrs;" | mysql -u root -p$ENV{MYSQL_ROOT_PASSWORD}] and die $!;
            }
        }
    }
}

sub _connect_opts {
    my ($self) = @_;
    my $storage = $self->storage;

    my %opts;

    given ($storage) {
        when (/SQLite/) {
            %opts = (
                brain => ($self->in_memory  ? ':memory:' : $self->get_brain),
                storage_args => {
                    in_memory => 0,
                },
            );
        }
        when (/Pg/) {
            %opts = (
                storage_args => {
                    dbname => $self->get_brain
                },
            );
        }
        when (/mysql/) {
            %opts = (
                storage_args => {
                    database => $self->get_brain,
                    host => 'localhost',
                    username => 'root',
                    password => $ENV{MYSQL_ROOT_PASSWORD},
                },
            );
        }
    }

    my %all_opts = (
        save_on_exit   => 0,
        storage_class  => $storage,
        %opts,
    );

    return %all_opts;
}

has storage => (
    is => 'ro',
    isa => 'Str',
);

# learn from various sources
sub train_megahal_trn {
    my ($self) = @_;
    $self->train_file("megahal.trn");
}

sub train_file {
    my ($self, $file) = @_;
    my $hailo = $self->hailo;

    my $f = $self->test_file($file);
    $hailo->train($f);
}

sub train_a_few_tokens {
    my ($self) = @_;
    my $hailo = $self->hailo;

    # Get some training material

    my @chr = map { chr } 50..120;
    my @random_tokens = map { $chr[rand @chr] } 1 .. 30;

    # Learn from it
    if ((int rand 2) == 1) {
        eval {
            $hailo->learn( \@random_tokens );
        };
    } else {
        eval {
            $hailo->learn( "@random_tokens" );
        };
    }

    return ($@, \@random_tokens);
}

sub test_congress {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    my $string = 'Congress shall make no law.';

    $hailo->learn($string);
    is($hailo->reply('make'), $string, "$storage: Learned string correctly");
}

sub test_congress_unknown {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    my $string = "Congress\t shall\t make\t no\t law.";
    my $reply  = $string;
    $reply     =~ tr/\t//d;

    $hailo->learn($string);
    is($hailo->reply('respecting'), $reply, "$storage: Got a random reply");
}

sub test_badger {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;
    my $brief = $self->brief;

    SKIP: {
        $self->train_filename("badger.trn");

        my $tests = $brief ? 5 : 50;
        skip "Badger test doesn't work with Words tokenizer", $tests + $tests * 5 * 2;

        for (1 .. $tests) {
            for (1 .. 5) {
                my $reply = $hailo->reply("badger");
                like($reply,
                    qr/^(! )?Badger!(?: Badger!)+/,
                 "$storage: Badger badger badger badger badger badger badger badger badger badger badger badger");
               pass("$storage: Mushroom Mushroom");
            }
            pass("$storage: A big ol' snake - snake a snake oh it's a snake");
        }
    }

    return;
}

sub train_filename {
    my ($self, $filename, $lines) = @_;
    my $hailo   = $self->hailo;
    my $storage = $self->storage;
    my $file    = $self->test_file($filename);
    my $fh      = $self->test_fh($filename);
    my $lns     = $lines // count_lines($file);

    for my $l (1 .. $lns) {
        chomp(my $_ = <$fh>);
        pass("$storage: Training line $l/$lns of $filename: $_");
        $hailo->learn($_);
    }
}

sub test_megahal {
    my ($self, $lines) = @_;
    my $hailo   = $self->hailo;
    my $storage = $self->storage;
    my $file    = $self->test_file("megahal.trn");
    my $lns     = $lines // count_lines($file);
    $lns        = ($self->brief) ? 30 : $lns;


    $self->train_filename("megahal.trn", $lns);
    my @tokens = $self->some_tokens("megahal.trn", $lns * 0.1);

    for (@tokens) {
        my $reply = $hailo->reply($_);
        ok(defined $reply, "$storage: Got a reply to <<$_>> = <<$reply>>");
    }

    return;
}

sub test_timtoady {
    my ($self, $lines) = @_;
    my $filename = "TimToady.trn";
    my $hailo    = $self->hailo;
    my $storage  = $self->storage;
    my $file     = $self->test_file($filename);
    my $fh       = $self->test_fh($filename);
    my $lns      = $lines // count_lines($file);
    $lns         = ($self->brief) ? 30 : $lns;

    $self->train_filename($filename, $lns);

    my @tokens = $self->some_tokens($filename, $lns * 0.5);
    for (@tokens) {
        my $reply = $hailo->reply($_);
        ok(defined $reply, "$storage: Got a reply to <<$_>> = <<$reply>>");
    }

    while (my $line = <$fh>) {
        chomp $line;
        my $reply = $hailo->reply($line);
        ok(defined $reply, "$storage: Got a reply to <<$line>> = <<$reply>>");
    }

    return;
}

sub test_babble {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    for (1 .. 10) {
        my ($err, $tokens) = $self->train_a_few_tokens();

        my $input = $tokens->[5];
        my $reply = $hailo->reply($input);
        # Hailo replies
        cmp_ok(length($reply) * 2, '>', length($input), "$storage: Hailo knows how to babble, said '$reply' given '$input'");
    }
}

sub test_starcraft {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;


  SKIP: {
    skip "$storage: We have to implement a method for clearing brains, or construct a new brain for each test", 4;

    $self->train_filename("starcraft.trn");

    ok(defined $hailo->reply("Gogogo"), "$storage: Got a random reply");
    ok(defined $hailo->reply("Naturally"), "$storage: Got a random reply");
    ok(defined $hailo->reply("Slamming"), "$storage: Got a random reply");

    my %reply;
    for (1 .. 500) {
        $reply{ $hailo->reply("that") } = 1;
    }

    is_deeply(
        \%reply,
        {
            "Ah, fusion, eh? I'll have to remember that." => 1,
            "I copy that." => 1,
            "I hear that." => 1,
            "I really have to remember that." => 1,
            "Oh, is that it?" => 1,
        },
        "$storage: Make sure we get every possible reply"
    );
  }
}

sub test_all_plan {
    my ($self) = @_;
    my $storage = $self->storage;

  SKIP: {
    my $ok = $self->spawn_storage();

    plan skip_all => "Skipping $storage tests, can't create storage" unless $ok;
    if ($self->exhaustive) {
        plan(tests => 29947);
        $self->test_exhaustive;
    } else {
        plan(tests => 977);
        $self->test_all;
    }
  }
}

sub test_stats {
    my ($self, $test_name) = @_;
    state $last_token = 0;
    state $last_expr = 0;
    state $last_prev = 0;
    state $last_next = 0;

    my ($token, $expr, $prev, $next) = $self->hailo->stats();

    cmp_ok($last_token, "<=", $token, "token count is <= since last time from $last_token to $token");
    cmp_ok($last_expr, "<=", $expr, "expr count is <= since last time from $last_expr to $expr");
    cmp_ok($last_prev, "<=", $prev, "prev count is <= since last time from $last_prev to $prev");
    cmp_ok($last_next, "<=", $next, "next count is <= since last time from $last_next to $next");

    ($last_token, $last_expr, $last_prev, $last_next) = ($token, $expr, $prev, $next);

    return;
}

sub test_all {
    my ($self) = @_;

    ok($self->hailo->_storage->ready(), "Storage object is ready for testing");

    for (all_tests()) {
        $self->$_;
        $self->test_stats($_);
    }

    return;
}

sub test_exhaustive {
    my ($self) = @_;

    ok($self->hailo->_storage->ready(), "Storage object is ready for testing");

    for (exhaustive_tests()) {
        $self->$_;
        $self->test_stats($_);
    }

    return;
}

sub some_tokens {
    my ($self, $file, $lines) = @_;
    $lines //= 50;
    my $trn = slurp($self->test_file($file));

    my @trn = split /\n/, $trn;
    my @small_trn = @trn[0 .. min(scalar(@trn), $lines)];
    my $toke = Hailo::Tokenizer::Words->new;
    my @trn_tokens = map { @{ $toke->make_tokens($_) } } @small_trn;
    my @token_refs = shuffle(@trn_tokens);
    my @tokens;
    push @tokens, $_->[1] for @token_refs;

    @tokens = @tokens[0 .. $lines];

    return @tokens;
}

sub test_fh {
    my ($self, $file) = @_;

    my $f = $self->test_file($file);

    open my $fh, '<:encoding(utf8)', $f;
    return $fh;
}

sub test_file {
    my ($self, $file) = @_;

    my $hailo_test = $INC{"Hailo/Test.pm"};
    $hailo_test =~ s[/[^/]+$][];

    my $path = catfile($hailo_test, 'Test', $file);

    return $path;
}

sub DEMOLISH {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    $self->unspawn_storage();
}

__PACKAGE__->meta->make_immutable;
