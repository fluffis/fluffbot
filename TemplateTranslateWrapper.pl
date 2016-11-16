#!/usr/bin/perl

use strict;
use warnings;

my $d;
if(defined $ARGV[0]) {
    $d = $ARGV[0];
}
else {
    $d = `date -d "1 day ago" '+%Y%m%d'`;
}
chomp($d);
chdir("/data/project/perfectbot/Fluffbot");
`bunzip2 -c /public/dumps/incr/svwiki/$d/svwiki-$d-pages-meta-hist-incr.xml.bz2 | perl TemplateTranslatePreparseXML.pl web | perl Templatetranslate.pl --runmode list --stdin --origin cite_web --target Webbref`;
`bunzip2 -c /public/dumps/incr/svwiki/$d/svwiki-$d-pages-meta-hist-incr.xml.bz2 | perl TemplateTranslatePreparseXML.pl book | perl Templatetranslate.pl --runmode list --stdin --origin cite_book --target Bokref`;
`bunzip2 -c /public/dumps/incr/svwiki/$d/svwiki-$d-pages-meta-hist-incr.xml.bz2 | perl TemplateTranslatePreparseXML.pl news | perl Templatetranslate.pl --runmode list --stdin --origin cite_news --target Tidningsref`;
