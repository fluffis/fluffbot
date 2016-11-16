#!/usr/bin/perl

# Fluffbot restoring templates
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

my $bot = Perlwikipedia->new("fluffbot");
my $debug = 1;

my $filepath = "/data/project/perfectbot/Fluffbot/krattmallar/";

$bot->set_wiki("sv.wikipedia.org", "w");

$bot->{debug} = 0;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

open(INF, "<$filepath/kratta_sandbox.txt");
my $text = Encode::decode("utf-8", join("", <INF>));
close(INF);
$bot->edit("Wikipedia:Sandl\x{e5}dan", $text, "Krattar sandl\x{e5}dan");
sleep 30;

open(INF, "<$filepath/kratta_hinkenochspaden.txt");
$text = Encode::decode("utf-8", join("", <INF>));
close(INF);
$bot->edit("Mall:Hinken och spaden", $text, "\x{c5}terst\x{e4}ller testmall");
sleep 30;

open(INF, "<$filepath/kratta_spadenochhinken.txt");
$text = Encode::decode("utf-8", join("", <INF>));
close(INF);
$bot->edit("Mall:Spaden och hinken", $text, "\x{c5}terst\x{e4}ller testmall");
sleep 30;

open(INF, "<$filepath/kratta_testmall.txt");
$text = Encode::decode("utf-8", join("", <INF>));
close(INF);
$bot->edit("Mall:Testmall", $text, "\x{c5}terst\x{e4}ller testmall");
