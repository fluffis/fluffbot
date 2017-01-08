#!/usr/bin/perl

# Fluffbot will work through a list and remove rubriken "Sverige" if none 
# of the links match the article name.
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
use Text::Diff;

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
open(FF, "</data/project/perfectbot/Fluffbot/RemoveSvenskaForgreningar.txt") || die("Could not open listfile: $!");
while(my $f = <FF>) {
    chomp($f);

    push @articles, $f;

}
close(FF);

foreach my $art (@articles) {
    next if(!$art);
#    warn $art;
    my $text = $bot->get_text($art);

    my $expectedname = $art;
    $expectedname =~ s/\ \(olika\ betydelser(\ \d)?\)//;

    my $newtext = "";

    my $inSwedish = 0;
    my $linkcount = 0;
    my $errorcount = 0;
    foreach my $row (split('\n', $text)) {

	if($row =~ /^\=\=\ Sverige\ \=\=/) {
#	    warn "Swedish section found!";
	    $inSwedish = 1;
	}
	if($inSwedish) {
	    if($row =~ /^\#\ \[\[([^\]]+)\]\]/) {
		my $linkmatch = $1;
#		warn "Link found";
		$linkcount++;
		if($row !~ /\[\[$expectedname\b/ && $linkmatch =~/(\x{e4}|\x{c4}|\x{e5}|\x{c5}|\x{d6}|\x{f6})/) {
#		    warn "Link doesn't match $art";
		    $errorcount++;
		}
	    }
	    elsif($row =~ /^\=\=\ / && $row !~ /^\=\=\ Sverige\ \=\=/) {
		$row = "\n" . $row;
		$inSwedish = 0;
	    }
	    elsif($row =~ /^\{\{Robotskapad\ f\x{f6}rgrening\}\}/) {
		$row = "\n" . $row;
		$inSwedish = 0;
	    }
	}


	    

	if(!$inSwedish) {
	    $newtext .= $row . "\n";
	}
    }

    if($errorcount > 0) {
	$newtext =~s/\[\[Kategori\:Robotskapade\ Sverigef\x{f6}rgreningar\]\]\n//;
    }
    else {
	next;
    }


    if($newtext ne $text && $errorcount == $linkcount) {
#	warn "Errorcount $errorcount";
#	warn "Linkcount $linkcount";
#	print diff \$text, \$newtext;

#	print "\nEdit $art? [Y/n] ";
#	my $input = <STDIN>;
#	chomp($input);
#	if($input !~ /^n/i) {
#	    $bot->edit($art, $newtext, "Tar bort felaktiga robotskapade Sverigef\x{f6}rgreningar ");
#	}
	print $art. "\n";

    }

    sleep 1;
}
