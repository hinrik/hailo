use 5.010;
use strict;
use warnings;
use Data::Section -setup;
use Test::More tests => 100;
use Hailo::Tokenizer::Words;

my $self = bless {} => __PACKAGE__;

my $text = ${ $self->section_data("Twitter names") };
my @names = split /\n/, $text;

my $toke = Hailo::Tokenizer::Words->new();


for (my $i = 0; $i < @names; $i++) {
    my $name = $names[$i];
    my $parsed = $toke->make_tokens($name);

    is_deeply($parsed, [[0, $name]], "Twitter name #$i ($name) was parsed correctly");
}

# Twitter names were made with:
## cat ~avar/g/bot-twatterhose/twatterhose.txt |tr ' ' '\n'|ack --output '$1' '(^@[^:.,]+)'|grep ^@|head -n 100

__DATA__
__[ Twitter names ]__
@emir_pasya
@shinta_amelia
@SweetYoungDiva
@justinbieber
@missnovia
@damndann
@debastard
@damndann
@jimparedes
@pablo_vfr
@fmlopez48
@shellawijayanti
@astridindah
@Q_Qwulandari
@Nocturnaljunke
@doleface
@colinferri
@nabiscuit
@thomasverrette
@highfivesurprise
@toddglass
@AsiFrio
@UrbanInformer
@Reza_zodzkee
@ardhitafebyanna
@ErnestoChavana
@desta80s
@baharidendy
@OhMrHILL
@ariiia
@adistihapsariii
@ihatequotes
@rizashahab
@NhuNhupisz
@AdlyFayruz
@mellySHE
@melizzaadriana
@fadin_jbox
@JuLySumange
@EkaNwt
@imuuul
@Navaa
@imuuul
@Navaa
@imuuul
@Awesome_Kitty
@tommy_indra
@danamanik
@pigglet88
@Sexstrology
@kapanlagicom
@ajiz1
@FarOutAkhtar
@dutchcowboys
@LOYALMUKA_BEZEL
@la_Givenchy
@m0delchiikxUSG
@KingofdaCliff
@DamnItsTrue
@radenzulfikar
@anggajanuar
@hephs_thighs
@rachelrita
@rarasquash
@herdianaditya
@Fithardiansyah
@cabrowns
@onesthename
@MKanellisWebs
@MariaLKanellis
@grizel
@stephenfry
@fairy_bread
@intanpa
@reyhanendika
@tracyann_mato
@clickfive
@kpdkpd
@benromans
@joeyzehr
@joeguese
@JDBieberPack
@Ngeow
@davideryanto
@Marchel_158
@Kristieetran
@pwgdochi
@vaselinemen
@putiariia
@fridalarasati
@TIPESULTAN
@Leratomollo
@Laurazhar
@imaimi
@fridalarasati
@bebekikuk
@ghasfar
@ASIFKHAN007
@sawogedhe
@audii_prast
