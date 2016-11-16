#!/usr/bin/perl

# Fluffbot updating expired templates.
# Copyright (C) User:Fluff 2014

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

$| = 1;
use lib "/data/project/perfectbot/Fluffbot/perlwikipedia-fluff/lib";

use strict;
use Perlwikipedia;
use Encode;
use Data::Dumper;
use Getopt::Std;
use Text::Diff;
#use Date::Manip;
use DateTime;

# lal - last active list
# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");
$bot->{debug} = 1;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $dt = DateTime->now;

my %u;
my $page = "'''Senast uppdaterad: " . $dt->ymd . " " . $dt->hms . " UTC'''\n\n";

for("Samtliga utg\x{E5}ngna b\x{E4}st f\x{F6}re", 
    "B\x{e4}st f\x{F6}re inom 1 m\x{E5}nad",
    "B\x{e4}st f\x{F6}re om 1 - 12 m\x{E5}nader",
    "B\x{e4}st f\x{F6}re om mer \x{E4}n 1 \x{E5}r",
    ) {

    $page .= qq!== [[:Kategori:$_]] ==\n!;
    if(my @pages = $bot->get_pages_in_category("Kategori:$_")) {
	foreach(@pages) {
	    $page .= "# [[:$_]]\n";
	}
    }
    else {
	$page .= qq!'''Inga sidor i kategorin.'''!;
    }
    $page .= "\n\n";

}

#print $page;

$bot->edit("Wikipedia:Projekt uppdatering/B\x{E4}st f\x{F6}re", $page, "Uppdaterar per " . $dt->ymd . " " . $dt->hms . " UTC");

