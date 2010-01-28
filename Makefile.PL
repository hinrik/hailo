use strict;
use warnings;
use inc::Module::Install '0.92';

name           ('Hailo');
perl_version   ('5.008001');
author         ('Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>');
abstract_from  ('lib/Hailo.pm');
version_from   ('lib/Hailo.pm');
install_script ('script/hailo');
license        ('perl');
homepage       ('http://search.cpan.org/dist/Hailo');
githubmeta     ();
bugtracker     ('http://github.com/hinrik/hailo/issues');
resources      (Ratings => 'http://cpanratings.perl.org/d/Hailo');

requires       ('Data::Section'              => '0');
requires       ('DBD::SQLite'                => '0');
requires       ('File::CountLines'           => '0');
requires       ('List::MoreUtils'            => '0');
requires       ('Moose'                      => '0');
requires       ('MooseX::Getopt'             => '0');
requires       ('MooseX::Types::Path::Class' => '0');
requires       ('MooseX::Types'              => '0');
requires       ('MooseX::Types::Moose'       => '0');
requires       ('namespace::clean'           => '0');
requires       ('Template'                   => '0');
requires       ('Term::ProgressBar'          => '2.00');
requires       ('Text::Trim'                 => '0');
recommends     ('DBD::Pg'                    => '0');

tests_recursive();
test_requires  ('Test::More'   => '0');
test_requires  ('Test::Script' => '0');
test_requires  ('Data::Random' => '0');

author_requires('Perl::Critic'        => '1.098');
# uncomment when the distro becomes installable via cpanp(1)
#author_requires('Perl::Critic::Moose' => '0');
author_requires('Test::Perl::Critic'  => '0');
author_requires('Test::Pod'           => '1.41');
author_requires('Test::Pod::Coverage' => '1.08');
author_tests   ('xt');

WriteAll();
