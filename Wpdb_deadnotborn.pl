#!/usr/bin/perl

# Fluffbot listing people that has a category for death but none for birth
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


# Listar artiklar som har en kategori för avlidna men ej för födda.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $sth = $dbh->prepare(qq!SELECT cat_title FROM category WHERE cat_title RLIKE ?!);
$sth->execute(qq!^Avlidna_!);

my @goodcats;
while($_ = $sth->fetchrow_array()) {
    push @goodcats, $_;	
}

# För alla i respektive kategori, leta reda på titlar:
$sth = $dbh->prepare(qq!SELECT cl_from FROM categorylinks WHERE cl_to = ? ORDER BY cl_from!);
my $sth2 = $dbh->prepare(qq!SELECT cl_from FROM categorylinks WHERE cl_to RLIKE ? AND cl_from = ?!);

my %notborn;
foreach my $fcat (@goodcats) {
    $sth->execute($fcat);
    while(my $page = $sth->fetchrow_array()) {
	$sth2->execute(qq!^Födda_!, $page);
	unless($sth2->rows()) {
#	    push @notborn, [$fcat, $page];
	    push @{$notborn{$fcat}}, $page;
	}
    }
}

$sth = $dbh->prepare(qq!SELECT page_title FROM page WHERE page_id = ? AND page_namespace = ?!);
my $pagetext = "Detta är en lista över sidor som har en kategori för när de avled men inte när de föddes. Borde kanske införas i [[:Kategori:Födda okänt år]]?\n\n";

foreach(sort yearsort keys %notborn) {
    
    my $i = 0;
    my $cattext = "";
    my $curcatname = $_;
    $curcatname =~ s/\_/\ /g;
    $cattext = "\n===Kategori [[:Kategori:$_|$curcatname]]===\n";
    
    foreach my $page (@{$notborn{$_}}) {
	$sth->execute($page, 0);
	if($sth->rows()) {
	    my $pagetitle = $sth->fetchrow_array();
	    $pagetitle =~ s/\_/\ /g;
	    next if($pagetitle =~ /^Avlidna/);
	    $cattext .= "* [[:$pagetitle]]\n";
	    $i++;
	}
    }
    $pagetext .= $cattext if($i);
}

$bot->edit("User:Fluffbot/Avlidna men inte f\x{f6}dda", Encode::decode("utf-8", $pagetext), "Uppdaterar listan");




sub anynumbersort {
    $a =~ /(\d+)/;
    my $anum = $1;
    $b =~ /(\d+)/;
    my $bnum = $1;
    
    $anum <=> $bnum;

}

sub yearsort {
    $a =~ /(\d+)/;
    my $anum = $1;
    $b =~ /(\d+)/;
    my $bnum = $1;

    if($a =~ /ok\x{e4}nt\ \x{f5}r/) {
	$anum = -9999;
    }
    if($b =~ /ok\x{e4}nt\ \x{e5}r/) {
	$bnum = -9999;
    }
    

    if($a =~ /\-talet/) {
	$anum -= .5;
    }
    if($b =~ /\-talet/) {
	$bnum -= .5;
    }

    if($a =~ /f\.kr/i) {
	$anum = $anum * -1;
    }
    if($b =~ /f\.kr/i) {
	$bnum = $bnum * -1;
    }


    $anum <=> $bnum;

}
