#!/usr/bin/perl

# Fluffbot will work through a list and check if the pages linked from the 
# disambiguation pages is symetric or asymetric
# Copyright (C) User:Fluff 2013

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use lib "/data/project/perfectbot/Fluffbot/perlwikipedia-fluff/lib";
use strict;
use Perlwikipedia;
use Encode;

use Data::Dumper;

binmode STDOUT, ':utf8';

my $bot = Perlwikipedia->new("fluffbot");
my $debug = 1;

my $filepath = "/data/project/perfectbot/Fluffbot/krattmallar/";

$bot->set_wiki("sv.wikipedia.org", "w");

$bot->{debug} = 0;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);
close(P);

$bot->login("Fluffbot", $pwd);

my @articles;
open(FF, "</data/project/perfectbot/Fluffbot/ListAsymetricDisambiguation.txt") || die("Could not open listfile: $!");
while(my $f = <FF>) {
    chomp($f);

#    $f =~ /^\#\ \[\[\:([^\]]+)\]\]/;
#    $f = $1;
    push @articles, $f;

}
close(FF);

foreach my $art (@articles) {
    next if(!$art);
#    warn $art;
    my $text = $bot->get_text($art);

    my $subart = $art;
    $subart =~ s/\ \(olika\ betydelser(\ \d)?\)//;

    my @forkpages = $text =~ /\# \[\[([^\]]+)\]\]/g;
    my $links = $#forkpages + 1;
    my $matchcounter = 0;
    foreach my $fp (@forkpages) {
	if($fp =~ /$subart/) {
	    $matchcounter++;
	}
    }
    print "$art;$links;$matchcounter;" . join("|", @forkpages) . "\n";

    sleep 1;
}
