#!/usr/bin/perl

# Updates a table at https://sv.wikipedia.org/wiki/Wikipedia:Projekt_k%C3%A4llh%C3%A4nvisningar#Artiklar_som_beh%C3%B6ver_k%C3%A4llor_indelade_efter_%C3%A4mnesomr%C3%A5de
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

use LWP::UserAgent;
use JSON::PP;

use POSIX;

use utf8;
binmode STDOUT, ":utf8";

# Fluff@svwp.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();

my $ua = LWP::UserAgent->new();
$ua->agent("Fluffbot\@svwp/1.0");

# $botname can be either Fluffbot or Perfect
my $botname = "Fluffbot";

open(P, "</data/project/perfectbot/.pwd-$botname") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);


$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";
$bot->login({ lgname => $botname, lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $urlbase = "https://petscan.wmflabs.org/?language=sv&project=wikipedia&depth=3&combination=subset&negcats=&ns%5B0%5D=1&larger=&smaller=&minlinks=&maxlinks=&before=&after=&max_age=&show_redirects=no&edits%5Bbots%5D=both&edits%5Banons%5D=both&edits%5Bflagged%5D=both&page_image=any&ores_type=any&ores_prob_from=&ores_prob_to=&ores_prediction=any&templates_yes=&templates_any=&templates_no=&outlinks_yes=&outlinks_any=&outlinks_no=&links_to_all=&links_to_any=&links_to_no=&sparql=&manual_list=&manual_list_wiki=&pagepile=&search_query=&search_wiki=&search_max_results=500&wikidata_source_sites=&subpage_filter=either&common_wiki=auto&source_combination=&wikidata_item=no&wikidata_label_language=&wikidata_prop_item_use=&wpiu=any&sitelinks_yes=&sitelinks_any=&sitelinks_no=&min_sitelink_count=&max_sitelink_count=&labels_yes=&cb_labels_yes_l=1&langs_labels_yes=&labels_any=&cb_labels_any_l=1&langs_labels_any=&labels_no=&cb_labels_no_l=1&langs_labels_no=&format=json&output_compatability=quick-intersection&sortby=none&sortorder=ascending&regexp_filter=&min_redlink_count=0&output_limit=&doit=Do%20it%21&interface_language=en&active_tab=tab_output&categories=Alla%20artiklar%20som%20beh%C3%B6ver%20k%C3%A4llor%0D%0A";

my @areas = (
    'Författare',
    'Musiker',
    'Politiker',
    'Idrottare',
    'Skådespelare',
    'Konstnärer',
    'Djur',
    'Hästar',
    'Fåglar',
    'Film',
    'Television',
    'Astronomi',
    'Geovetenskap',
    'Historia',
    'Arkeologi',
    'Biologi',
    'Fysik',
    'Kemi',
    'Teknik',
    'Bilar',
    'Trafik',
    'Sport',
    'Fotboll',
    'Ishockey',
    'Handboll',
    'Basket',
    'Språk',
    'Medicin',
    'Arkitektur',
    'Litteratur',
    'Mat',
    'Meteorologi',
    'Klimatologi',
    'Krig',
    'Fred',
    'Politisk verksamhet',
    'Levande personer'
);

my $outputdata = qq!{{#switch: {{{1}}}\n!;
foreach(@areas) {
    print "Fetching $_\n";
    my $req = HTTP::Request->new(GET => $urlbase . $_);
    my $response = $ua->request($req);
    if($response->is_success()) {
	my $res = JSON::PP->new->utf8->decode($response->content);
	$outputdata .= qq!| $_ = ! . $res->{pagecount} . qq!\n!;
    }
    else {
	print "Error fetching data for $_: " . $response->status_line . "\n";
	die;
    }
    print "... fetch complete, sleeping 30 seconds\n";
    sleep 30;
}
$outputdata .= qq!| #default = \n!;
$outputdata .= qq!| uppdateringsdatum = ! . strftime "%F %T", gmtime time;
$outputdata .= qq!}}\n!;

$bot->edit({
    action => 'edit',
    bot => 1,
    title => "Wikipedia:Projekt k\x{e4}llh\x{e4}nvisningar/\x{c4}mnestabelldata",
    minor => 1,
    text => $outputdata,
    summary => "[[User:Fluffbot|Robot]] uppdaterar data"
	   });
