#!/usr/bin/perl

# Fluffbot lists the latest moves that are made between namespaces
# Copyright (C) User:Fluff 2016

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

use warnings;
use strict;

use Data::Dumper;
use MediaWiki::API;
use Text::Diff;
use DBI;
use Getopt::Long;

binmode STDOUT, 'utf8';
use utf8;

# Fluff@svwp.

my %namespaces = (
    -1 => "Special",
    0 => "",
    1 => "Talk",
    2 => "User",
    3 => "User talk",
    4 => "Project",
    5 => "Project talk",
    6 => "File",
    7 => "File talk",
    8 => "MediaWiki",
    9 => "MediaWiki talk",
    10 => "Template",
    11 => "Template talk",
    12 => "Help",
    13 => "Help talk",
    14 => "Category",
    15 => "Category talk"
    );



my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();


$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";

open(P, "</data/project/perfectbot/.pwd-Perfect") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login({ lgname => "Perfect", lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $pagetitle = "User:HangsnaBot/Flyttar";
my $orgpage = $bot->get_page({title => $pagetitle});

my $text = "{| class=\"wikitable\"\n|-\n! N !! Från !! Till !! Vem !! När \n";
my @result;


my $moves = $bot->list({
    action => "query",
    list => "logevents",
    lelimit => 500,
    letype => "move"
		       });
my $c = 0;
foreach(@{$moves}) {
    if($_->{ns} ne $_->{params}->{target_ns}) {
	$c++;
	$_->{timestamp} =~ s/[Z]//g;
	$_->{timestamp} =~ s/[T]/\ /g;
	$text .= qq!|-\n|$c\n!;
	$text .= qq!|[[:$_->{title}|$_->{title}]]\n!;
	$text .= qq!|[[:$_->{params}->{target_title}|$_->{params}->{target_title}]]\n!;
	$text .= qq!|{{anv|! . $_->{user} . qq!}}\n!;
	$text .= qq!|$_->{timestamp}\n!;
    }
}
$text .= "|}";

$bot->edit({
    action => "edit",
    title => $pagetitle,
    basetimestamp => $orgpage->{timestamp},
    text => $text,
    summary => "Listar sidflyttar mellan namnrymder i ett urval av de senaste 500 flyttarna"
	   }, ) || die("$bot->{error}->{code}: $bot->{error}->{details}");
