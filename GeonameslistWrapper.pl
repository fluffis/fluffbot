#!/usr/bin/perl


chdir("/data/project/perfectbot/Fluffbot");
`bunzip2 -c /public/dumps/public/svwiki/20161220/svwiki-20161220-pages-meta-current.xml.bz2 | perl Geonameslist.pl > geonameslist.txt`;
