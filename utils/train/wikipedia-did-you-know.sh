#!/bin/bash

# See http://en.wikipedia.org/wiki/Template:DYK_archive_nav
for i in $(seq 1 252); do
    wget http://en.wikipedia.org/wiki/Wikipedia:Recent_additions_$i -O $i.html
done

pv *html | html2text -width 500|grep '\.\.\.that' | perl -pe 's/.*?\.\.\.that[, ]\s*//; s/^(.)/\U$1/; s/_/ /g' > wp.trn
