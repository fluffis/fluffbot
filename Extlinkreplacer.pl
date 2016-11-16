#!/usr/bin/perl

# Fluffbot edits external links
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

require 'common.pl';


use Data::Dumper;
use Perlwikipedia;
use Text::Diff;
use Term::ReadKey;
use Getopt::Long;

# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");
#$bot->{debug} = 1;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);


my $datum = `/bin/date +"%Y-%m"`;
chomp($datum);

my $months_sv = {
    'januari' => "01",
    'februari' => "02",
    'mars' => "03",
    'april' => "04",
    'maj' => "05",
    'juni' => "06",
    'juli' => "07",
    'augusti' => "08",
    'september' => "09",
    'oktober' => "10",
    'november' => "11",
    'december' => "12"
};

my $months_en = {
    'january' => "01",
    'february' => "02",
    'mars' => "03",
    'april' => "04",
    'may' => "05",
    'june' => "06",
    'july' => "07",
    'august' => "08",
    'september' => "09",
    'october' => "10",
    'november' => "11",
    'december' => "12"
};

my $fn = $ARGV[0];
chomp($fn);

my @articles = getpagenames($fn);

foreach my $article (@articles) {

    my $an = "";
    if($article->{ns}) {
	$an .= $article->{ns} . ":";
    }
    $an .= $article->{article};
    my $orgtext = $bot->get_text($an);
    my $newtext = $orgtext;
    my @links = $orgtext =~ /(http\:\/\/w{0,3}\.?dn\.se[^\ |^\||^\]|^\<|^\n]+)/g;

    my @substitutions;
    foreach my $orglink (@links) {
	my $newlink = $orglink;

	if($orglink !~ /DNet\/jsp\/polopoly/ && $orglink =~ /\-/) {
	    my @t = split(/\-/, $newlink);

	    my $last = pop @t;
	    if($last =~ /\d\.\d+$/) {
		$newlink = join('-', @t);
	    }
	}

	if($newlink ne $orglink) {
	    push @substitutions, {
		original => $orglink,
		new => $newlink
	    };
	}
    }    

    foreach my $subst (@substitutions) {
	$newtext =~ s/$subst->{original}/$subst->{new}/g;
    }

    if($orgtext ne $newtext) {
	my $colornewtext = $newtext;
	$colornewtext =~ s/(http\:\/\/w{0,3}\.?dn\.se[^\ |^\||^\]|^\<|^\n]+)/\e\[43m\e\[30m$1\e\[0m/g;
	my $colororgtext = $orgtext;
	$colororgtext =~ s/(http\:\/\/w{0,3}\.?dn\.se[^\ |^\||^\]|^\<|^\n]+)/\e\[41m\e\[30m$1\e\[0m/g;
	print diff \$colororgtext, \$colornewtext;
	print "\nEdit $an? [Y/n] ";
	my $input = <STDIN>;
	chomp($input);
	if($input !~ /^n/i) {
	    $bot->edit($an, $newtext, "Updating link syntax to dn.se");
	}
	my $width;
	($width, undef, undef, undef) = GetTerminalSize();
	print "-" x $width;
	print "\n\n";

    }
    else {
	sleep 1;
    }
}
