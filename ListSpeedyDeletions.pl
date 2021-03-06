#!/usr/bin/perl

# Fluffbot lists speedy deletions
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

use utf8;

# Fluff@svwp.

my %namespaces = (
    -1 => "Special:",
    0 => "",
    1 => "Talk:",
    2 => "User:",
    3 => "User talk:",
    4 => "Project:",
    5 => "Project talk:",
    6 => "File:",
    7 => "File talk:",
    8 => "MediaWiki:",
    9 => "MediaWiki talk:",
    10 => "Template:",
    11 => "Template talk:",
    12 => "Help:",
    13 => "Help talk:",
    14 => "Category:",
    15 => "Category talk:"
    );



my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();

open(P, "</data/project/perfectbot/.pwd-Perfect") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);


$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";
$bot->login({ lgname => "Perfect", lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $pagetitle = "User:HangsnaBot/Snabbraderingar";
my $orgpage = $bot->get_page({title => $pagetitle});
my $sth = $dbh->prepare(qq!SELECT page_namespace, page_title FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE cl_to = ? ORDER BY page_title ASC!);

my $text = "\n{{/Topp}}\n==Senast körd {{subst:LOCALYEAR}}-{{subst:LOCALMONTH}}-{{subst:LOCALDAY2}}==\n";
my @result;

$sth->execute("Snabbraderingar");
if($sth->rows()) {
    while(my ($ns, $title) = $sth->fetchrow_array()) {
	next if(!$title);
	$title =~ s/\_/\ /g;
	$title = Encode::decode("utf-8", $title);
	push @result, $title;
	$text .= qq!* {{ejomdirigering|$namespaces{$ns}$title|$namespaces{$ns}$title}}\n!;
    }
}


my $sum = " för snabbradering";
if($#result == 0) {
    $sum = "1 sida ligger just nu anmäld" . $sum;
}
else {
    $sum = ($#result+1) . qq! sidor ligger just nu anmälda! . $sum;
}

$bot->edit({
    action => "edit",
    title => $pagetitle,
    basetimestamp => $orgpage->{timestamp},
    text => $text,
    summary => $sum
	   }, ) || die("$bot->{error}->{code}: $bot->{error}->{details}");

print $sum . "\n";
