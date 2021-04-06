#!/usr/bin/perl

# Fluffbot adds date to undated templates for artilces in need of actions
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

binmode STDOUT, 'utf8';

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

# Skapa kat om ej existerar. Hämta innehåll från vart?
# Flytta hämtning av kategorier och mallar till onwiki?
# Hantera om det finns en eller flera mallar i åtgärdsmallen

# Kontrollerar ej:
# Bäst för med felaktig parameter
# Artiklar som saknas uppföljning


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

# Fetch categories and templates
my $cattext = $bot->get_text("User:Fluffbot/Datumst\x{e4}mpling/Kategorier");
my @categories = grep { $_ !~ /^(Kategori|Category)/i } $cattext =~ /^\*\s*\[\[\:(Kategori|Category)\:([^\]|^\|]+)[\||\]]/img;


my $templatetext = $bot->get_text("User:Fluffbot/Datumst\x{e4}mpling/Mallar");
my @preloadtemplates = grep {$_ !~ /^(Mall|Template)/i } $templatetext =~ /^\*\s*\[\[\:?(Mall|Template)\:([^\]|^\|]+)[\||\]]/img;

# Get substitutions (listed as [[Mall:Org]] -> [[Mall:Substitute]]
my %tmplsubst;
foreach my $ttline (split(/\n/, $templatetext)) {
    if($ttline =~ /\]\]\s*\-\>\s*\[\[/) {
	$ttline =~ s/^\s*\*\s*//;
	$ttline =~ s/\s*\:?(Mall|Template)\://g;
	$ttline =~ s/\|([^\]]+)//g;
	$ttline =~ s/(\[\[|\]\])//g;
	my ($from, $to) = split(/\s*\-\>\s*/, $ttline);
	$tmplsubst{$from} = $to;
    }
}

my @nonedits;


my @tmpls;
foreach my $tmpl (@preloadtemplates) {
    push @tmpls, $tmpl unless(grep { $_ eq $tmpl } @tmpls);
}

foreach my $tmpl (@tmpls) {
    push @tmpls, map {$_->{title} =~ s/^Mall\://; $_->{title} } $bot->what_links_here_opts("Mall:$tmpl", "&namespace=10&hidetrans=1&hidelinks=1");
}

foreach my $category (@categories) {
    next if(!$category);

    my @pages = $bot->get_all_pages_in_category("Category:$category");
    print "Now scanning category $category\n";
    if(!$pages[0]) {
	print "No pages found in category $category\n";
    }
    else {
	foreach my $page (@pages) {
	    my $trackinginfo = "";

	    if($page =~ /^(Mall|Template)/) {
		print "Now scanning $page - page is template, skipping\n";
		next;
	    }

	    print "Now scanning page $page\n";
	    
	    my $orgtext = $bot->get_text($page);
	    my $newtext;
	    my @editedtemplates;
	    my $delay = 0;

	    foreach my $text (split(/\}\}/, $orgtext)) {
		if($delay > 0) {
		    $delay--;
		    if($delay == 0) {
			$text .= "|datum=$datum" unless($text =~ /datum\s*\=/);
		    }
		}

		$text .= qq!}}!;

		foreach my $tmpl (@tmpls) {
		    
		    # Special treatment...
		    if($text =~ /\{\{n\x{e4}r\?/i) {
			$text =~ s/\{\{n\x{e4}r\?/\{\{N\x{e4}r\/sub/i;
		    }
		    elsif($text =~ /\{\{\x{e5}r\?/i) {
			$text =~ s/\{\{\x{e5}r\?/\{\{\x{e5}r/i;
		    }
		    elsif($text =~ /\{\{vem\?/i) {
			$text =~ s/\{\{vem\?/\{\{vem/i;
		    }
		    elsif($text =~ /\{\{vilka\?/i) {
			$text =~ s/\{\{vilka\?/\{\{vilka/i;
		    }
		    elsif($text =~ /\{\{av\ vem\?/i) {
			$text =~ s/\{\{av\ vem\?/\{\{vem/i;
		    }


                    # Handle {{mall||2012-12-12}} and {{mall||2012-12}}
                    if($text =~ /\{\{$tmpl\s*\|([^\|]*)\|(\d{4}\-\d{2}\-?\d{0,2})\}\}/ix) {
                        my $d1 = $1;
                        my $d2 = $2;

                        if($d2 =~ /\d{4}\-\d{2}\-\d{2}/) {
                            $d2 =~ s/\-\d{0,2}$//;
                        }
                        $text =~ s/\{\{$tmpl\s*\|([^\|]*)\|(\d{4}\-\d{2}\-?\d{0,2}?)\}\}/\{\{$tmpl\|$d1\|datum\=$d2\}\}/i;

                        # When we've set parameters, we don't need the ||, so let's kick it.
                        if($text =~ /\|\|datum/) {
                           $text =~ s/\|\|datum/\|datum/;
                        }
                        push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
                    }
		    else {
			$trackinginfo .= qq!No match in $tmpl for "||YYYY-MM-DD" or "||YYYY-MM"\n!;
		    }

		    # Handle {{mall|2013-12}}
		    if($text =~ /\{\{$tmpl\s*\|\s*(\d{4}\-\d{2})\-?\d{0,2}\}\}/i) {
			my $d1 = $1;
			$text =~ s/\{\{$tmpl\s*\|\s*(\d{4}\-\d{2})\-?\d{0,2}\}\}/\{\{$tmpl\|datum\=$d1\}\}/i;
                        push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);			
		    }
		    else {
			$trackinginfo .= qq!No match in $tmpl for "|YYYY-MM"\n!;
		    }

		    # Handle {{tmpl|datum02016-03}}
		    if($text =~ /\{\{$tmpl\s*\|\s*datum0(\d{4}\-\d{2})/i) {
			$text =~ s/\{\{$tmpl\s*\|\s*datum0(\d{4}\-\d{2})/\{\{$tmpl\|datum=$1/i;
			push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
		    }

		    # Handle {{tmpl|asd|datum={{{1}}}}}
		    if($text =~ /\{\{$tmpl\s*\|[^\|]+\|\s*(date|datum)\s*\=\s*\{\{\{1\}\}\}/i) {
			$text =~ s/\|\s*(date|datum)\s*\=\s*\{\{\{1\}\}\}/\|datum\=$datum/;
			push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
		    }
		    
                    # Handle {{tmpl|asd|datum=November 2013}}
                    if($text =~ /\{\{$tmpl\s*\|[^\|]+\|\s*(date|datum)\s*\=\s*([^\ ]+)\ (\d{4})/i) {
                        my $msel = lc($2);
                        my $year = $3;
                        my $month = 0;
                        if(defined $months_sv->{$msel}) {
                            $month = $months_sv->{$msel};
                        }
                        elsif(defined $months_en->{$msel}) {
                            $month = $months_en->{$msel};
                        }
                        $text =~ s/\|\s*(date|datum)\s*\=\s*[^\ ]+\ \d{4}/\|datum\=$year-$month/;
                        push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
                    }
		    else {
			$trackinginfo .= qq!No match in $tmpl for "|Reason|datum=Month YYYY"\n!;
		    }

		    # Handle {{tmpl|datum=November 2013}}
		    if($text =~ /\{\{$tmpl\s*\|\s*(date|datum)\s*\=\s*([^\ ]+)\ (\d{4})/i) {
			my $msel = lc($2);
			my $year = $3;
			my $month = 0;
			if(defined $months_sv->{$msel}) {
                            $month = $months_sv->{$msel};
                        }
                        elsif(defined $months_en->{$msel}) {
                            $month = $months_en->{$msel};
                        }
                        $text =~ s/\|\s*(date|datum)\s*\=\s*[^\ ]+\ \d{4}/\|datum\=$year-$month/;
                        push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
                    }
		    else {
			$trackinginfo .= qq!No match in $tmpl for "|datum=Month YYY"\n!;
		    }


		    if($text =~ /(\{\{$tmpl\s*\|[^\}]+\}\})/i) {
			print "Match in template $tmpl: $1 - delay at $delay\n";
			$trackinginfo .= qq!Matching template "$tmpl": $1 (Delay: $delay)\n!;

			my $tmplmatch = $1;

			# Make exception for templates within templates
			if($tmplmatch =~ /\{\{[^\{]+\{/ && $delay == 0) {
			    $delay = $tmplmatch =~ m/\{\{/;
			    print "Found sub-templates, setting delay to $delay\n";
			    $trackinginfo .= qq!Found sub-templates in "$tmpl", setting delay to $delay\n!;

			    push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
			}

			if($tmplmatch !~ /(\|date|\|datum|\|m\x{e5}nad)/ && $delay == 0) {
			    $text =~ s/\}\}/\|datum\=$datum\}\}/;
			    push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
			}
			elsif($tmplmatch =~ /\|datum\=\x{C5}{4}\-MM/) {
			    # Handle {{tmpl|asd|datum=ÅÅÅÅ-MM}}
			    $text =~ s/\|datum\=\x{C5}\-MM/\|datum\)=$datum/;
			    push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
			}
		    }
		    
		    if($text =~ /\{\{$tmpl\}\}/i) {
			$text =~ s/\}\}/\|datum\=$datum\}\}/;
			push @editedtemplates, $tmpl unless(grep { $_ eq $tmpl } @editedtemplates);
		    }
		    else {
			$trackinginfo .= qq!No match for {{tmpl}}\n!;
		    }

		    if(grep { $_ eq $tmpl } keys %tmplsubst) {
			$text =~ s/\{\{$tmpl\s*(\||\})/\{\{$tmplsubst{$tmpl}$1/i;
		    }
		}
		$newtext .= $text;
	    }

	    $newtext =~ s/\}\}$// unless($orgtext =~ /\}\}$/);
	    
	    if($newtext ne $orgtext) {
		print diff \$orgtext, \$newtext;

		my $editsum = "Datumst\x{e4}mplar ";
		if($#editedtemplates == 0) {
		    $editsum .= "mall [[Mall:$editedtemplates[0]]]";
		}
		else {
		    $editsum .= "mallar " . join(", ", map { "[[Mall:$_]]" } @editedtemplates);
		}
#		print "\n";
#		print "$editsum";

#		print "\nEdit? [Y/n] ";
#		my $input = <STDIN>;
#		chomp($input);
#		if($input !~ /^n/i) {		
		    $bot->edit($page, $newtext, "$editsum");
		    sleep 10;
#		}
	    }
	    else {
		print "Didn't edit $page\n";
		push @nonedits, $page unless(grep { $page eq $_ } @nonedits);
	    }
	}
    }
}


# Uppdatera scannade men ick redigerade
my $pagetext = "{{User:Fluffbot/Datumst\x{e4}mpling/Resultat-header}}\n\n" . join("\n", map { "* [[:$_]]" } sort @nonedits);
$bot->edit("User:Fluffbot/Datumst\x{e4}mpling/Resultat", $pagetext, "Resultat av dagens k\x{f6}rning");
