use strict;
use warnings;
use 5.010;
use inc::Module::Install '0.92';

name           ('Hailo');
perl_version   ('5.010');
author         ('Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>');
abstract_from  ('lib/Hailo.pm');
version_from   ('lib/Hailo.pm');
install_script ('script/hailo');
no_index       (directory => 'utils');
license        ('perl');
homepage       ('http://search.cpan.org/dist/Hailo');
githubmeta     ();
bugtracker     ('http://github.com/hinrik/hailo/issues');
resources      (Ratings => 'http://cpanratings.perl.org/d/Hailo');

requires       ('autodie'                       => '2.08');
requires       ('Class::MOP'                    => '0.98');
requires       ('Data::Section'                 => '0.100270');
requires       ('DBD::SQLite'                   => '1.29');
requires       ('File::CountLines'              => '0.0.2');
requires       ('Getopt::Long::Descriptive'     => '0.083');
requires       ('IO::Interactive'               => '0.0.6');
requires       ('List::MoreUtils'               => '0.22');
requires       ('Log::Log4perl'                 => '1.27');
requires       ('Module::Pluggable'             => '3.9');
requires       ('Moose'                         => '0.94');
requires       ('MooseX::Getopt'                => '0.26');
requires       ('MooseX::Getopt::Dashes'        => '0');
requires       ('MooseX::Role::Strict'          => '0.03');
requires       ('MooseX::StrictConstructor'     => '0.08');
requires       ('MooseX::Types::Path::Class'    => '0.05');
requires       ('MooseX::Types'                 => '0.21');
requires       ('MooseX::Types::Moose'          => '0.21');
requires       ('namespace::clean'              => '0.13');
requires       ('Template'                      => '2.22');
requires       ('Term::ProgressBar'             => '2.00');
requires       ('Term::ReadLine::Gnu'           => '0');

# for the optional backends
recommends     ('CHI'                           => '0.34');
recommends     ('CHI::Driver::BerkeleyDB'       => '0.01');
recommends     ('CHI::Driver::File'             => '0');
recommends     ('CHI::Driver::Memory'           => '0');
recommends     ('DBD::mysql'                    => '4.013');
recommends     ('DBD::Pg'                       => '2.16.1');
recommends     ('Digest::MD4'                   => '1.5');

tests_recursive();
test_requires  ('Data::Random'    => '0.05');
requires       ('File::Slurp'     => '9999.13');
test_requires  ('Test::Exception' => '0.29');
test_requires  ('Test::More'      => '0.94');
test_requires  ('Test::Output'    => '0.16');
test_requires  ('Test::Script'    => '1.07');

author_requires('Perl::Critic'        => '1.098');
# uncomment when the distro becomes installable via cpanp(1)
#author_requires('Perl::Critic::Moose' => '0');
author_requires('Test::Perl::Critic'  => '1.02');
author_requires('Test::Pod'           => '1.41');
author_requires('Test::Pod::Coverage' => '1.08');
author_requires('Test::Script'        => '1.07');
author_tests   ('xt');

WriteAll();
