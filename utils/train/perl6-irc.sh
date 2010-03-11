#!/bin/bash

# Screen-scrape the perl6 irc logs

wget -q -O- http://irclog.perlgeek.de/perl6/ | grep /perl6 | perl -pe 's[.*href="/perl6/([0-9-]+)".*][$1]' | grep ^20 > days.txt

for i in $(sort -n days.txt); do
    wget "http://irclog.perlgeek.de/text.pl?channel=perl6;date=$i" -O $i.txt
done

ack -h '^\d\d:\d\d TimToady_?' *txt|perl -pe 's/.*TimToady_?\s+//' > TimToady.trn
