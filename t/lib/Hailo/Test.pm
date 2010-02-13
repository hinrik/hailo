package Hailo::Test;
use 5.10.0;
use autodie;
use Moose;
use Test::More;
use File::Spec::Functions qw(catdir catfile);
use Data::Random qw(:all);

sub simple_storages {
    return qw(Perl Perl::Flat DBD::SQLite)
}

has hailo => (
    is => 'ro',
    isa => "Hailo",
    lazy_build => 1,
);

sub _build_hailo {
    my ($self) = @_;
    my $storage = $self->storage;

    my $hailo = Hailo->new(
        print_progress => 0,
        storage_class => $storage,
        ($storage eq 'SQLite'
         ? (brain_resource => ':memory:')
         : ()
        ),
    );

    return $hailo;
}

has storage => (
    is => 'ro',
    isa => 'Str',
);

sub learn_megahal_trn {
    my ($self) = @_;
    my $hailo = $self->hailo;
}

sub learn_a_few_words {
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
    is($hailo->reply('respecting'), $string, "$storage: Got a random reply");
}

sub test_congress_again {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    my $string = "Congress\t shall\t make\t no\t law.";
    my $reply  = $string;
    $reply     =~ tr/\t//d;

    $hailo->learn($string);
    is($hailo->reply('make'), $reply, "$storage: Learned string correctly");
    is($hailo->reply('respecting'), $reply, "$storage: Got a random reply");
}

sub test_badger {
    my ($self) = @_;
    my $hailo = $self->hailo;
    my $storage = $self->storage;

    my $fh = $self->test_fh("badger.trn");

    $hailo->train($fh);

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

    say $path;

    return $path;
}

__PACKAGE__->meta->make_immutable;
