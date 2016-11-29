#!/usr/bin/perl

# Fluffbot lists biographies missing defaultsort
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

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();

open(P, "</data/project/perfectbot/.pwd-Perfect") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";
$bot->login({ lgname => "Perfect", lgpassword => $pwd }) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $pagetitle = "User:HangsnaBot/UtanStandardsortering";
my $orgpage = $bot->get_page({title => $pagetitle});
my $sth = $dbh->prepare(qq!SELECT page_title FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE cl_to = ? AND cl_sortkey_prefix = ? AND page_namespace = ?!);

my $text = "\n\n==Senast körd {{subst:LOCALYEAR}}-{{subst:LOCALMONTH}}-{{subst:LOCALDAY2}}==\n";
my @result;

for("Kvinnor", "Män", "Personer med alternativ könsidentitet") {

    $sth->execute($_, '', 0);
    if($sth->rows()) {
	while(my $title = $sth->fetchrow_array()) {
	    $title =~ s/\_/\ /g;
	    $title = Encode::decode("utf-8", $title);
	    push @result, $title;
	    $text .= qq!* [[:$title|$title]]\n!;
	}
    }
}

my $sum = " som saknar standardsortering";
if($#result == 0) {
    $sum = "1 artikel" . $sum;
}
else {
    $sum = ($#result+1) . qq! artiklar! . $sum;
}

$bot->edit({
    action => "edit",
    title => $pagetitle,
    basetimestamp => $orgpage->{timestamp},
    text => $text,
    summary => $sum
	   }, ) || die("$bot->{error}->{code}: $bot->{error}->{details}");

print $sum . "\n";
