#!/usr/bin/perl

# Fluffbot translates templates to swedish parameters, preparser
# Copyright (C) User:Fluff 2015

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

use strict;
use warnings;

use XML::LibXML::Reader;

my $r = XML::LibXML::Reader->new(FD => fileno(STDIN));

my $t = $ARGV[0];
chomp($t);

my $pattern;

if($t eq "web") {
    $pattern = qr/\{\{cite[\ |\_]?web/i;
}
elsif($t eq "book") {
    $pattern = qr/\{\{cite[\ |\_]?book/i;
}
elsif($t eq "news") {
    $pattern = qr/\{\{cite[\ |\_](news|article)/i;
}


while($r->nextElement('page')) {
    my $title;
    my $text;
    if($r->nextElement('title')) {
	$title = $r->readInnerXml();
    }
    if($r->nextElement('ns')) {
	if($r->readInnerXml() == 0) {
	    if($r->nextElement('text')) {
		$text = $r->readInnerXml();
	    }
	    
	    if($text =~ $pattern) {
		print $title . "\n";
	    }
	}
    }
}
