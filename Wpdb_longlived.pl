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


use lib "/data/project/perfectbot/Fluffbot/mediawikiapi/lib";

use DBI;
use Data::Dumper;
use Encode;
use MediaWiki::API;

require '/data/project/perfectbot/Fluffbot/common.pl';

my $bot = MediaWiki::API->new({ api_url => "https://sv.wikipedia.org/w/api.php" });

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login({ lgname => "Fluffbot", lgpassword => $pwd });

my $nslist = $bot->api({
    action => "query",
    meta => "siteinfo",
    siprop => "namespaces"
			});
my %ns;
foreach my $nsid (keys %{$nslist->{query}->{namespaces}}) {
    $ns{$nsid} = $nslist->{query}->{namespaces}->{$nsid}->{'*'};
}

# Hämta folk som enligt kategorierna har levt längre än 100 år.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;hostname=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $sth = $dbh->prepare(qq!SELECT cat_title FROM category WHERE cat_title RLIKE ? ORDER BY cat_title ASC!);
$sth->execute(qq!^Födda_[0-9]{4}\$!);

my @borncats;
while($_ = $sth->fetchrow_array()) {
    push @borncats, $_;
}

my $sth2 = $dbh->prepare(qq!SELECT cl_to FROM categorylinks WHERE cl_to RLIKE ? AND cl_from = ?!);

my @interesting;

foreach my $fcat(@borncats) {
    $sth = $dbh->prepare(qq!SELECT page_id, page_title, page_namespace FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE cl_to = ?!);
    $sth->execute($fcat);
    $fcat =~ /(\d{4})/;
    my $fyear = $1;
    while(my $page = $sth->fetchrow_hashref()) {
	$sth2->execute(qq!^Avlidna_[0-9]+\$!, $page->{page_id});
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

my $curcat = "";
my $pagetext = "Detta är en lista över personer födda efter år 1000 som är kategoriserade som både födda och avlidna och där differensen indikerar att de blev äldre än 100 år. Listan uppdaterades senast den " . getwikidate() . "\n\n";

foreach(sort SortByAgeAndArticleName @interesting) {
    my $pagens = $_->[0]->{page_namespace};
    my $pagetitle = $_->[0]->{page_title};
    $pagetitle =~ s/\_/\ /g;
    if($pagens == 0) {
	$pagetext .= "* [[:$pagetitle]]";
    }
    else {
	$pagetext .= "* [[:$ns{$pagens}:$pagetitle]]";
    }

    $pagetext .= " ([[:Kategori:$_->[1]|$_->[3]]] - [[:Kategori:$_->[2]|$_->[4]]], dvs ca " . ($_->[4] - $_->[3]) . " år)\n";
}

$bot->edit({
    action => "edit",
    bot => 1,
    title => "User:Fluffbot/Folk \x{f6}ver 100 \x{e5}r", 
    text => Encode::decode("utf-8", $pagetext), 
    summary => "Uppdaterar listan"
});


sub SortByAgeAndArticleName {

    my $aage = $a->[4] - $a->[3];
    my $bage = $b->[4] - $b->[3];

    if($aage == $bage) {
	return $a->[0]->{page_title} cmp $b->[0]->{page_title};

    }
    else {
	return $bage <=> $aage;
    }
}
