#!/bin/bash

# Script to update http://v.nix.is/~avar/cover_db/coverage.html

HTMP=/tmp/hailo-cover

rm -rf $HTMP
mkdir $HTMP
cd $HTMP
git clone --no-hardlinks ~avar/g/hailo
cd hailo

export TEST_POSTGRESQL=1
export TEST_MYSQL=1
export HARNESS_OPTIONS=j1
# Must set $MYSQL_ROOT_PASSWORD externally

perl -I ~avar/g/dist-zilla/lib -I ~avar/g/dist-zilla-plugin-readmefrompod/lib -Iinc $(which dzil) build
cd Hailo-*
perl Makefile.PL
cover -test

rm -rfv ~avar/www/cover_db
rsync -av --progress /tmp/hailo-cover/hailo/Hailo-0.*/cover_db ~avar/www/
sudo chown -R avar:www-data ~avar/www/cover_db
sudo chmod -R 775 ~avar/www/cover_db

