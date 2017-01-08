#!/usr/bin/perl

# Fluffbot listing people that has been alive for more than 100 years.
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

use DBI;
use Data::Dumper;
use Encode;
use Perlwikipedia;

require '/data/project/perfectbot/Fluffbot/common.pl';

my $bot = Perlwikipedia->new("fluffbot");
$bot->set_wiki("sv.wikipedia.org", "w");

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my %ns = $bot->get_namespace_names();

# Hämta folk som enligt kategorierna har levt längre än 100 år.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;hostname=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $sth = $dbh->prepare(qq!SELECT cat_title FROM category WHERE cat_title RLIKE ? ORDER BY cat_title ASC!);
$sth->execute(qq!^Födda_[0-9]{4}\$!);

my @borncats;
while($_ = $sth->fetchrow_array()) {
    push @borncats, $_;
}

my $sth2 = $dbh->prepare(qq!SELECT cl_to FROM categorylinks WHERE cl_to RLIKE ? AND cl_from = ?!);

my @interesting;

foreach my $fcat(@borncats) {
    $sth = $dbh->prepare(qq!SELECT cl_from FROM categorylinks WHERE cl_to = ?!);
    $sth->execute($fcat);
    $fcat =~ /(\d{4})/;
    my $fyear = $1;
    while(my $page = $sth->fetchrow_array()) {
	$sth2->execute(qq!^Avlidna_[0-9]+\$!, $page);
	if($sth2->rows()) {
	    my $acat = $sth2->fetchrow_array();
	    $acat =~ /(\d+)/g;
	    my $ayear = $1;
	    if($ayear - $fyear > 100) {
		push @interesting, [$page, $fcat, $acat, $fyear, $ayear];
	    }
	}
    }
    $sth = undef;
}

$sth = $dbh->prepare(qq!SELECT page_namespace, page_title FROM page WHERE page_id = ?!);
my $curcat = "";
my $pagetext = "Detta är en lista över personer födda efter år 1000 som är kategoriserade som både födda och avlidna och där differensen indikerar att de blev äldre än 100 år. Listan uppdaterades senast den " . getwikidate() . "\n\n";

foreach(sort {$a->[4] - $a->[3] <=> $b->[4] - $b->[3] } @interesting) {
    $sth->execute($_->[0]);
    my ($pagens, $pagetitle) = $sth->fetchrow_array();
    $pagetitle =~ s/\_/\ /g;
    if($pagens == 0) {
	$pagetext .= "* [[:$pagetitle]]";
    }
    else {
	$pagetext .= "* [[:$ns{$pagens}:$pagetitle]]";
    }

    $pagetext .= " ([[:Kategori:$_->[1]|$_->[3]]] - [[:Kategori:$_->[2]|$_->[4]]], dvs ca " . ($_->[4] - $_->[3]) . " år)\n";
}


$bot->edit("User:Fluffbot/Folk \x{f6}ver 100 \x{e5}r", Encode::decode("utf-8", $pagetext), "Uppdaterar listan");
