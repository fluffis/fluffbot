#!/usr/bin/perl

# Fluffbot 
# Copyright (C) User:Fluff 2017

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

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my @categories;

#	push @categories, GetRecursiveCategoryTree("Berg_efter_land");
for(qw(/Vattenfall_efter_land Vattendrag_efter_land Öar_efter_land Halvöar_efter_land Stränder_efter_land Dalar_efter_land/) {

	push @categories, GetRecursiveCategoryTree($_);
	
}
open(INFILE, "<allarticles") || die "Could not open articles file: $!";
my $row;
my $sth = $dbh->prepare(qq!SELECT cl_to FROM category_link LEFT JOIN page ON page_id = cl_from WHERE page_title = ? AND page_namespace = 0!);
while($row = <INFILE>) {
	chomp($row);
	$sth->execute($row);
	while(my $tocat = $sth->fetchrow_array()) {
		if(grep { $tocat eq $_ } @categories) {
			# Match!
			RemoveElevation($row);
		}
	}
	
}


sub RemoveElevation {
	my $article = shift;
	
	my $orgtext = $bot->get_text($article);
	my $newtext = $orgtext;
	
	$newtext =~ s/(\|\s*elevation\s*\=)\s*)(\d+)/$1/i;
	
	print diff \$orgtext, \$newtext;
	if($orgtext ne $newtext) {
		print "\nEdit? [Y/n] ";
		my $input = <STDIN>;
		chomp($input);
		if($input !~ /^n/i) {
			$bot->edit($article, $newtext, "Tar bort parametern elevation från robotskapade artiklar");
		}
	}
}


sub GetRecursiveCategoryTree {

    my $cat = shift;
    my @categories;
    my $sth = $dbh->prepare(qq!SELECT page_id, page_namespace, page_title FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE cl_to = ?!);
    $sth->execute($cat);

    while(my $ref = $sth->fetchrow_hashref()) {
        if($ref->{page_namespace} == 14) {
            push @categories, GetRecursiveCategoryTree($ref->{page_title});
            push @categories, $ref->{page_title};
        }
    }
    return @categories;
}

sub GetArticlesFromCategory {

	my $cat = shift;
	my @pages;
	my $sth = $dbh->prepare(qq!SELECT page_namespace, page_title FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE cl_to = ?!;
	$sth->execute($cat);
	
	
	while(my $ref = $sth->fetchrow_hashref()) {
		if($ref->{page_namespace} == 0) {
			push @pages, $ref->{page_title};
		}
	}
	
	return @pages;
}