#!/usr/bin/perl

# Add a category to each article. Articles are provided via a list
# Copyright (C) User:Fluff 2019

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
use Encode;

use utf8;
binmode STDOUT, ":utf8";

# Fluff@svwp.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();

# $botname can be either Fluffbot or Perfect
my $botname = "Fluffbot";

open(P, "</data/project/perfectbot/.pwd-$botname") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";
$bot->login({ lgname => $botname, lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $cat = "Ledam\x{f6}ter av Royal Society";

my $fn = $ARGV[0];
chomp($fn);

open(IN, $fn) || die "Could not open input file: $!";
while(my $art = <IN>) {
    chomp($art);
    my $a2 = Encode::decode("utf-8", $art);
    my $page = $bot->get_page({title => $a2});
    my $newtext = $page->{'*'};
    $newtext =~ s/(\[\[(Kategori|Category)(.*\]\]))(?!\n\[\[(Category|Kategori))/$1\n\[\[Kategori\:$cat\]\]/igm;

    if($newtext ne $page->{'*'}) {
	print diff \$page->{'*'}, \$newtext;
	print "\nEdit $art? [Y/n] ";
	my $input = <STDIN>;
	chomp($input);
	if($input !~ /^n/i) {
	    $bot->edit({
		action => 'edit',
		bot => 1,
		title => $a2, 
		minor => 1,
		basetimestamp => $page->{timestamp},
		text => $newtext, 
		summary => "+[[Kategori:$cat]]"
		       });
	}
    }
    else {
	print "$art not modified\n";
    }
    print "\n";
}
