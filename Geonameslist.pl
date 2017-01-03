#!/usr/bin/perl

# Parse XML dump and create a CSV of articles with geonames set.
# Copyright (C) User:Fluff 2017

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
use DBI;
use IO::Handle;

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p;mysql_read_timeout=3600", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $sth = $dbh->prepare(qq!SELECT * FROM categorylinks WHERE cl_from = ? AND cl_to LIKE ?!);

my $r = XML::LibXML::Reader->new(FD => fileno(STDIN));

open(F, ">/data/project/perfectbot/Fluffbot/geonameslist.txt") || die("Could not open file: $!");
F->autoflush(1);
#print F "Title\tGeonamesid\tCountry\tType\n";

my $i = 0;
while($r->nextElement('page')) {
    my $title;
    my $text;
    my $id;
    my $ns;

    $i++;
    warn "Scanned $i pages" if($i % 10000 == 0);

    if($r->nextElement('title')) {
	$title = $r->readInnerXml();
    }

    if($r->nextElement('ns')) {
	$ns = $r->readInnerXml();
    }

    if($r->nextElement('id')) {
	$id = $r->readInnerXml();
    }

    if($r->nextElement('text')) {
	$text = $r->readInnerXml();
    }

    if($title && $text && $id && $ns == 0) {
	my $geonames;
	my $country;
	my $type;

	$sth->execute($id, 'Wikipedia:Artiklar_med_geonames-parameter_utan_P1566%');
	if($sth->rows()) {
	    
	    $text =~ /\|\ *1\ *\=\ *([^\n|^\|]+)/;
	    $type = $1;
	    
	    $text =~ /\|\ *geonames\ *\=\ *([^\n|^\|]+)/;
	    $geonames = $1;
	    $geonames =~ s/(\ |\t)+$//g;
	    
	    $text =~ /\|\ *country\ *\=\ *([^\n|^\|]+)/;
	    $country = $1;
	    $country =~ s/\[\[//g;
	    $country =~ s/\]\]//g;
	    
	    warn "$title";
	    print F "$title\t$geonames\t$country\t$type\n";
	}

    }

}
