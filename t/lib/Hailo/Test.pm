package Hailo::Test;
use 5.010;
use autodie;
use Moose;
use Hailo;
use Test::More;
use File::Spec::Functions qw(catdir catfile);
use Data::Random qw(:all);
use File::Slurp qw(slurp);
use List::Util qw(shuffle min);
use File::Temp qw(tempfile tempdir);
use File::CountLines qw(count_lines);
use Hailo::Tokenizer::Words;

sub simple_storages {
    return qw(Perl Perl::Flat DBD::SQLite)
}

sub flat_storages {
    return qw(Perl::Flat)
}

sub all_storages {
    return qw(Perl Perl::Flat CHI::Memory CHI::File CHI::BerkeleyDB DBD::mysql DBD::SQLite DBD::Pg);
}

sub chain_storages {
    return qw(Perl Perl::Flat);
}

has tmpdir => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

sub _build_tmpdir {
    # Dir to store our brains
    my $dir = tempdir( CLEANUP => 1 );

    return $dir;
}

has brain_resource => (
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

sub brain {
    my ($self) = @_;

    return $self->brain_resource // $self->tmpfile->[1];
}

sub spawn_storage {
    my ($self) = @_;
    my $storage = $self->storage;
    my $brainrs = $self->brain;
    my $ok = 1;

    my %classes = (
        Pg                => 'DBD::Pg',
        mysql             => 'DBD::mysql',
        'CHI::File'       => 'CHI::Driver::File',
        'CHI::Memory'     => 'CHI::Driver::Memory',
        'CHI::BerkeleyDB' => 'CHI::Driver::BerkeleyDB',
    );

    if (exists $classes{$storage}) {
        eval { Class::MOP::load_class($classes{$storage}) };
        return if $@;
    }

    given ($storage) {
        when (/Pg/) {
            # It doesn't use the file to store data obviously, it's just a convenient random token.
            if (system "createdb '$brainrs' >/dev/null 2>&1") {
                $ok = 0;
            } else {
                # Kill Pg notices
                $SIG{__WARN__} = sub { print STDERR @_ if $_[0] !~ m/NOTICE:\s*CREATE TABLE/; };
            }
        }
        when (/mysql/) {
            if (system qq[echo "SELECT DATABASE();" | mysql -u'hailo' -p'hailo' 'hailo' >/dev/null 2>&1]) {
                $ok = 0;
            } else {
                system q[echo 'drop table info; drop table token; drop table expr; drop table next_token; drop table prev_token;' | mysql -u hailo -p'hailo' hailo];
            }
        }
    }

    return $ok;
}

sub unspawn_storage {
    my ($self) = @_;
    my $storage = $self->storage;
    my $brainrs = $self->brain;

    given ($storage) {
        when (/Pg/) {
            system "dropdb '$brainrs'";
        }
        when (/SQLite/) {
            $_->finish for values %{ $self->hailo->_storage_obj->sth };
            $self->hailo->_storage_obj->dbh->disconnect;
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
                brain_resource => ($self->brain || ':memory:')
            ),
        }
        when (/Perl/) {
            %opts = (
                brain_resource => $self->brain,
            ),
        }
        when (/Pg/) {
            %opts = (
                storage_args => {
                    dbname => $self->brain
                },
            );
        }
        when (/mysql/) {
            %opts = (
                storage_args => {
                    database => 'hailo',
                    host => 'localhost',
                    username => 'hailo',
                    password => 'hailo',
                },
            );
        }
        when (/CHI::(?:BerkeleyDB|File)/) {
            %opts = (
                storage_args => {
                    root_dir => $self->tmpdir,
                },
            );
        }
    }

    my %all_opts = (
        print_progress => 0,
        storage_class => $storage,
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

sub train_a_few_words {
    my ($self) = @_;
    my $hailo = $self->hailo;

    # Get some training material
    my $size = 10;
    my @random_words = rand_words( size => $size );

    # Learn from it
    eval {
        $hailo->learn("@random_words");
    };

    return ($@, \@random_words);
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

    $self->train_filename("badger.trn");

    for (1 .. 50) {
        for (1 .. 5) {
            my $reply = $hailo->reply("badger");
            like($reply,
                 qr/^(! )?Badger!(?: Badger!)+/,
                 "$storage: Badger badger badger badger badger badger badger badger badger badger badger badger");
            pass("$storage: Mushroom Mushroom");
        }
        pass("$storage: A big ol' snake - snake a snake oh it's a snake");
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
    $lns        = 100 if $storage ~~ /File/;

    for my $l (1 .. $lns) {
        chomp(my $_ = <$fh>);
        pass("$storage: Training line $l/$filename: $_");
        $hailo->learn($_);
    }
}
sub test_megahal {
    my ($self, $lines) = @_;
    my $hailo   = $self->hailo;
    my $storage = $self->storage;

    $self->train_filename("megahal.trn", $lines);
    my @words = $self->some_words("megahal.trn", $lines, 50);

    for (@words) {
        my $reply = $hailo->reply($_);
        ok(defined $reply, "$storage: Got a reply to $_");
    }

    return;
}

sub test_chaining {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;
    my $brainrs = $self->brain;

    my $prev_brain;
    for my $i (1 .. 10) {
        my $test = (ref $self)->new(
            storage => $storage,
            brain_resource => $brainrs,
        );

        if ($prev_brain) {
            my $this_brain = $test->hailo->_storage_obj->_memory;
            is_deeply($prev_brain, $this_brain, "$storage: Our previous $storage brain matches the new one, try $i");
        }

        my ($err, $words) = $test->train_a_few_words();

        # Hailo replies
        cmp_ok(length($test->hailo->reply($words->[5])) * 2, '>', length($words->[5]), "$storage: Hailo knows how to babble, try $i");

        # Save this brain for the next iteration
        $prev_brain = $test->hailo->_storage_obj->_memory;

        $test->hailo->save();
    }
}

sub test_all_plan {
    my ($self, $restriction) = @_;
    my $storage = $self->storage;    

  SKIP: {
    my $ok = $self->spawn_storage();

    plan skip_all => "Skipping $storage tests, can't create storage" unless $ok;
    if (defined $restriction && $restriction eq 'known') {
        plan(tests => 953);
        $self->test_known;
    }
    else {
        plan(tests => 954);
        $self->test_all;
    }
    $self->unspawn_storage();
  }
}

sub test_known {
    my ($self) = @_;

    for (qw(test_congress test_badger test_megahal)) {
        $self->$_;
    }

    return;
}

sub test_all {
    my ($self) = @_;

    for (qw(test_congress test_congress_unknown test_badger test_megahal)) {
        $self->$_;
    }

    return;
}

sub some_words {
    my ($self, $file, $lines) = @_;
    $lines //= 50;
    my $trn = slurp($self->test_file($file));

    my @trn = split /\n/, $trn;
    my @small_trn = @trn[0 .. min(scalar(@trn), $lines)];
    my $words = Hailo::Tokenizer::Words->new;
    my @trn_words = map { $words->make_tokens($_) } @small_trn;
    my @words = shuffle($words->find_key_tokens(\@trn_words));

    @words = @words[0 .. 50];

    return @words;
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

__PACKAGE__->meta->make_immutable;
