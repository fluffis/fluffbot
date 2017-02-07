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

my @categories = GetRecursiveCategoryTree("Robotskapade_geografiartiklar");

my @pages;
foreach my $cat (sort @categories) {
	push @pages, GetArticlesFromCategory($cat);
}

foreach my $p (sort @pages) {
	print "$p\n";
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