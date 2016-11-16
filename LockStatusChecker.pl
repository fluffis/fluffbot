#!/usr/bin/perl

# Fluffbot checks locked pages to verify that the correct template is
# in place. Also removes lock templates when lock expires.
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

use warnings;
use strict;

use Data::Dumper;
use Perlwikipedia;
use Text::Diff;

use Getopt::Long;

use DBI;

# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");
#$bot->{debug} = 1;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, { RaiseError => 1, AutoCommit => 1});



my @tmpls = qw/Halvlåst Låst/;
my $sth = $dbh->prepare(qq!SELECT * FROM page LEFT JOIN templatelinks ON tl_from = page_id LEFT JOIN page_restrictions ON page_id = pr_page WHERE tl_namespace = ? AND tl_title = ? AND pr_type = ?!);
foreach my $tmpl (@tmpls) {
    warn $tmpl;
    $sth->execute(10, $tmpl, "edit");
    while(my $r = $sth->fetchrow_hashref()) {
	if(!defined $r->{pr_page}) {
	    # No page restriction remaining, remove template
	    my $text = $bot->get_text($r->{page_title});
	    $text =~ s/\{\{$tmpl([^\}]*)\}\}//i;
	    $bot->edit($r->{page_title}, $text, "Tar bort {{$tmpl}}");
	}
    }
}
