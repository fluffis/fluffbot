#!/usr/bin/perl

# Fluffbot listing people that has more then one category for birth or death.
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
use Perlwikipedia;

require '/data/project/perfectbot/Fluffbot/common.pl';

my $bot = Perlwikipedia->new("fluffbot");
$bot->set_wiki("sv.wikipedia.org", "w");

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my %ns = $bot->get_namespace_names();

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $sth = $dbh->prepare(qq!SELECT cat_title FROM category!);
$sth->execute();

my @goodcats;
my @borncats;
while($_ = $sth->fetchrow_array()) {
    if(/^Avlidna\_(\d+)$/) {
        push @goodcats, $_;
    }
    elsif(/^Födda\_(\d+)$/) {
	push @borncats, $_;
    }
}

# För alla i respektive kategori, leta reda på titlar:
$sth = $dbh->prepare(qq!SELECT cl_from FROM categorylinks WHERE cl_to = ?!);
my $sth2 = $dbh->prepare(qq!SELECT cl_to FROM categorylinks WHERE cl_to RLIKE ? AND cl_from = ?!);
my @morethenone;
my @alreadyseen;
foreach my $fcat (@goodcats) {
    $sth->execute($fcat);
    while(my $page = $sth->fetchrow_array()) {
        next if(grep {$page eq $_->[0] } @morethenone);
        $sth2->execute(qq!Avlidna_[0-9]+!, $page);
        if($sth2->rows() > 1) {
            my @cats;
            while($_ = $sth2->fetchrow_array()) {
                push @cats, $_;
            }
            push @morethenone, [$page, [@cats]];
        }
    }
}

$sth = $dbh->prepare(qq!SELECT page_namespace, page_title FROM page WHERE page_id = ?!);
my $curcat = "";
my $pagetext = "Denna sida listar personer som har mer än en kategori för när de avled. Uppdaterades senast: " . getwikidate() . "\n\n";
foreach(sort {$a->[0] <=> $b->[0] } @morethenone) {
    $sth->execute($_->[0]);
    my ($pagens, $pagetitle) = $sth->fetchrow_array();
    $pagetitle =~ s/\_/\ /g;
    if($pagens == 0) {
	$pagetext .= "* [[:$pagetitle]] (";
    }
    else {
	$pagetext .= "* [[:" . $ns{$pagens} . ":$pagetitle]] (";
    }

    $pagetext .= join(", ", map { $_ =~ s/\_/\ /g; "[[:Kategori:$_|$_]]" } @{$_->[1]});
    $pagetext .= ")\n";
}

$bot->edit("User:Fluffbot/D\x{f6}da tv\x{e5} g\x{e5}nger om", utftoiso($pagetext), "Uppdaterar lista");


#### Och här gör vi samma sak fast med födda också


# För alla i respektive kategori, leta reda på titlAr:
$sth = $dbh->prepare(qq!SELECT cl_from FROM categorylinks WHERE cl_to = ?!);
$sth2 = $dbh->prepare(qq!SELECT cl_to FROM categorylinks WHERE cl_to RLIKE ? AND cl_from = ?!);
@morethenone = ();
@alreadyseen = undef;
foreach my $fcat (@borncats) {
    $sth->execute($fcat);
    while(my $page = $sth->fetchrow_array()) {
        next if(grep {$page eq $_->[0] } @morethenone);
        $sth2->execute(qq!Födda_[0-9]+!, $page);
        if($sth2->rows() > 1) {
            my @cats;
            while($_ = $sth2->fetchrow_array()) {
                push @cats, $_;
            }
            push @morethenone, [$page, [@cats]];
        }
    }
}

$sth = $dbh->prepare(qq!SELECT page_namespace, page_title FROM page WHERE page_id = ?!);
$curcat = "";
$pagetext = "Denna sida listar personer som har mer än en kategori för när de föddes. Uppdaterades senast: " . getwikidate() . "\n\n";
foreach(sort {$a->[0] <=> $b->[0] } @morethenone) {
    next if(!$_);
    $sth->execute($_->[0]);
    my ($pagens, $pagetitle) = $sth->fetchrow_array();
    $pagetitle =~ s/\_/\ /g;
    if($pagens == 0) {
	$pagetext .= "* [[:$pagetitle]] (";
    }
    else {
	$pagetext .= "* [[:" . $ns{$pagens} . ":$pagetitle]] (";
    }

    $pagetext .= join(", ", map { $_ =~ s/\_/\ /g; "[[:Kategori:$_|$_]]" } @{$_->[1]});
    $pagetext .= ")\n";
}

$bot->edit("User:Fluffbot/F\x{f6}dda tv\x{e5} g\x{e5}nger om", utftoiso($pagetext), "Uppdaterar lista");
