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
use utf8;
use Text::Diff;

binmode STDOUT, ":utf8";

require '/data/project/perfectbot/Fluffbot/common.pl';

my $bot = Perlwikipedia->new("fluffbot");
$bot->set_wiki("sv.wikipedia.org", "w");

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my %ns = $bot->get_namespace_names();

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1});
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);

open(INFILE, "<:encoding(UTF-8)", "activecategories") || die "Could not open active categories file: $!";
my @categories;
while(my $row = <INFILE>) {
    chomp($row);
    push @categories, $row;
}
close(INFILE);
warn "Reading categories done";

open(INFILE, "<:encoding(UTF-8)", "allarticles") || die "Could not open articles file: $!";
my $row;
my $sth = $dbh->prepare(qq!SELECT cl_to FROM categorylinks LEFT JOIN page ON page_id = cl_from WHERE page_title = ? AND page_namespace = 0!);
while($row = <INFILE>) {
        chomp($row);
        print $row . "\n";
        $sth->execute($row);
        while(my $tocat = $sth->fetchrow_array()) {
                if(grep { $tocat eq $_ } @categories) {
                        # Match!
                        RemoveElevation($row);
			last;
                }
        }

}

sub RemoveElevation {
    my $article = shift;

    my $orgtext = $bot->get_text($article);
    my $newtext = $orgtext;

    $newtext =~ s/(\|\s*elevation\s*\=\s*)(\d+)/\1/i;

    print diff \$orgtext, \$newtext;
    if($orgtext ne $newtext) {
#	print "\nEdit? [Y/n] ";
#	my $input = <STDIN>;
#	chomp($input);
#	if($input !~ /^n/i) {
	$bot->edit($article, $newtext, "Tar bort parametern elevation från robotskapade artiklar");
	sleep 3;
#	}
    }
}
