#!/usr/bin/perl

# Fluffbot updating statistics
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

my $hour = `TZ=Europe/Stockholm /bin/date +%H`;
chomp($hour);

die "Hour not 00 or 12" unless($hour eq "00" || $hour eq "12");

my $bot = Perlwikipedia->new("fluffbot");
my $debug = 0;

$bot->set_wiki("sv.wikipedia.org", "w");
#$bot->{debug} = 0;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $text = $bot->get_text("Wikipedia:Statistik/Statistik");
#$text .= "\n* {{subst:LOCALDAY}} {{subst:LOCALMONTHNAME}} {{subst:LOCALYEAR}}, {{subst:LOCALTIME}} - {{subst:NUMBEROFARTICLES}} artiklar, {{subst:NUMBEROFUSERS}} anv\x{e4}ndare (varav {{subst:NUMBEROFACTIVEUSERS}} aktiva), {{subst:#expr: ({{subst:NUMBEROFARTICLES:R}}-235100)/ (({{subst:#time: U | {{subst:LOCALTIME}} }} / 86400) - ({{subst:#time: U | 2007-06-20T18:43:00+00:00 }} / 86400)) round 2}} artiklar/dag sedan 23 maj 2001";

$text .= "\n* {{subst:LOCALDAY}} {{subst:LOCALMONTHNAME}} {{subst:LOCALYEAR}}, {{subst:LOCALTIME}} - {{subst:NUMBEROFARTICLES}} artiklar, {{subst:NUMBEROFUSERS}} anv\x{e4}ndare (varav {{subst:NUMBEROFACTIVEUSERS}} aktiva), {{subst:#expr: {{subst:NUMBEROFARTICLES:R}}/ (({{subst:#time:  U | {{subst:CURRENTTIMESTAMP}} }}  / 86400) -  ({{subst:#time: U | 23 May 2001 10:01:00 }} / 86400)) round 2}} artiklar/dag sedan 23 maj 2001";
unless($bot->edit("Wikipedia:Statistik/Statistik", $text, "[[User:Fluffbot|Robot]] uppdaterar statistik")) {
    print "Edit was not successful.";
}

$bot->set_wiki("sv.wikimini.org", "w");

$bot->{debug} = 1;

$bot->login("Fluffbot", $pwd);

$text = $bot->get_text("Wikimini:Statistik/Statistik");
#$text .= "\n* {{subst:LOCALDAY}} {{subst:LOCALMONTHNAME}} {{subst:LOCALYEAR}}, {{subst:LOCALTIME}} - {{subst:NUMBEROFARTICLES}} artiklar, {{subst:NUMBEROFUSERS}} anv\x{e4}ndare (varav {{subst:NUMBEROFACTIVEUSERS}} aktiva), {{subst:#expr: ({{subst:NUMBEROFARTICLES:R}}-235100)/ (({{subst:#time: U | {{subst:LOCALTIME}} }} / 86400) - ({{subst:#time: U | 2007-06-20T18:43:00+00:00 }} / 86400)) round 2}} artiklar/dag sedan 23 maj 2001";

$text .= "\n* {{subst:LOCALDAY}} {{subst:LOCALMONTHNAME}} {{subst:LOCALYEAR}}, {{subst:LOCALTIME}} - {{subst:NUMBEROFARTICLES}} artiklar, {{subst:NUMBEROFUSERS}} anv\x{e4}ndare (varav {{subst:NUMBEROFACTIVEUSERS}} aktiva), {{subst:#expr: {{subst:NUMBEROFARTICLES:R}}/ (({{subst:#time:  U | {{subst:CURRENTTIMESTAMP}} }}  / 86400) -  ({{subst:#time: U | 16 September 2013 00:00:00 }} / 86400)) round 2}} artiklar/dag sedan 16 september 2013";
unless($bot->edit("Wikimini:Statistik/Statistik", $text, "[[User:Fluffbot|Robot]] uppdaterar statistik")) {
    print "Edit was not successful.";
}
