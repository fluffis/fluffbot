#!/usr/bin/perl

# Fluffbot translates templates to swedish parameters
# Copyright (C) User:Fluff 2014 - 2016

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

$| = 1;
use lib "/data/project/perfectbot/Fluffbot/perlwikipedia-fluff/lib";
use warnings;
use strict;

use DBI;

use Data::Dumper;
use Perlwikipedia;
use Text::Diff;

use JSON::PP;

use Getopt::Long;

use utf8;
binmode STDOUT, ":utf8";

# 2do
# Borde testa om mallen har blivit översatt.
# Need to glue together when a template contains a template.
# One is easy to find but we need a loop around it.
# One level of subtemplates is ok unlimited.
# need to detect when swedish params is used in a template with english names


# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");
my $debug = 1;
my $autoedit = 0;
$bot->set_wiki("sv.wikipedia.org", "w");
#$bot->{debug} = 1;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);
my $dbh;
my $dbhp;

sub reconnect {
    $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p;mysql_read_timeout=3600", undef, undef, {RaiseError => 1, AutoCommit => 1});

    $dbhp = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=tools.labsdb;database=s51592__perfectbot", undef, undef, {RaiseError => 1, AutoCommit => 1});
}

reconnect();

my $datum = `/bin/date +"%Y-%m-%d"`;
chomp($datum);

my $alltemplates = $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Mallar");

my $flag_debugmode = 0;
my $flag_runmode = "normal";
my $flag_help = 0;
my $param_target = '';
my $param_origin = '';
my $param_file = '';
my $param_onlytemplate = '';
my $param_stdin = 0;
GetOptions("debug" => \$flag_debugmode,
	   "help" => \$flag_help,
	   "runmode=s" => \$flag_runmode,
	   "target=s" => \$param_target,
	   "origin=s" => \$param_origin,
	   "file=s" => \$param_file,
	   "onlytemplate=s" => \$param_onlytemplate,
	   "stdin" => \$param_stdin
    );

if($flag_help) {
    print "Options: --runmode [normal|list]\n";
    print "* normal (default) will check the latest timestamps of all templates\n";
    print "* list will require --file --target --origin to take a premade list\n";
    print "--origin <template> defines which template we are searching to replace\n";
    print "--target <template> defines which template we should translate INTO. Case sensitive\n.";
    print "--file <filename> defines a file with articles (separated with newline) to scan\n";
    print "--stdin use stdin to retrieve articles instead of --file\n";
    print "--debug to activate debugmode\n";
    print "--onlytemplate <template> will only run the given template\n";
    exit;

}


# debugger
if($flag_debugmode) {
    # $article = "Article_with_us";
    my $article = "Giordano_Bruno";

    # $target = "Svenskt_namn";
    my $target = "Tidskriftsref";
    # $origin = "Cite_journal";
    my $origin = "Cite_journal";
    my $tmpl_wous = $origin;
    $tmpl_wous =~ s/\_/\ /g;
    my $enctext = Encode::encode("utf-8", $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Parametrar/" . $target . ".js"));
    my $settings = JSON::PP->new->utf8->decode($enctext);
    my $text = $bot->get_text($article);
    my($res, $newtext) = substitute($article, $tmpl_wous, $settings, $text);
    if($res == -1) {
	print "$article is still in error. Faulty parameters: " . join(", ", @{$newtext}) . "\n";
	exit;
    }
    elsif($res == -2) {
	print "$article is still in error. It has sub-templates\n";
	exit;
    }

    $newtext =~ s/\}\}$// unless($text =~ /\}\}$/);
    print diff \$text, \$newtext;
    my $editsum = "\x{d6}vers\x{e4}tter k\x{e4}llmall: [[Mall:$tmpl_wous]]";

    print "\nEdit? [Y/n] ";
    my $input = <STDIN>;
    chomp($input);
    if($input !~ /^n/i) {
	$bot->edit($article, $newtext, "$editsum");
    }
    exit;
}

if($flag_runmode eq "list") {

    die "Params origin, target and file needs to be defined" if(!$param_target || !$param_origin || (!$param_file && !$param_stdin));
    die "File not found!" if($param_file && !-f $param_file);

    chomp($param_target);
    chomp($param_origin);

    my $tmpl_wous = $param_origin;
    $tmpl_wous =~ s/\_/\ /g;
    my $enctext = Encode::encode("utf-8", $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Parametrar/" . $param_target . ".js"));
    my $settings = JSON::PP->new->utf8->decode($enctext);


    scan_errorpages($param_origin, $settings);

    my $L;

    if($param_file) {
	open($L, '<:encoding(UTF-8)', $param_file) || die "Could not open file $param_file: $!";
    }
    else {
	$L = *STDIN;
    }

    use Devel::Peek;
    my $errorpages;

    my $current_errorpage = $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$param_target");
    $current_errorpage = "" if($current_errorpage eq "2");
    my @existing_errorpages;
    foreach my $r(split(/\n/, $current_errorpage)) {
	$r =~ /\*\ \[\[:([^\]]+)\]/;
	push @existing_errorpages, $1;
    }

    while(my $article = <$L>) {
	chomp($article);
	$article =~ s/\x{feff}//;
	$article =~ s/\r//;
	print "Looking for $article\n";
#	Dump $article;
	my $text = $bot->get_text($article);

	print "Found: " . substr($text, 0, 10) . "\n";

	my($res, $newtext) = substitute($article, $tmpl_wous, $settings, $text);
	if($res < 0) {
	    print "$article has an error: $res\n";
	    if($res == -1) {
		$errorpages .= qq!* [[:$article]] (Template: [[Mall:$tmpl_wous]], Error: Unmatched parameters, Parameters: ! . join(", ", @{$newtext}) . qq!, Date: $datum)\n! unless(grep { $_ eq $article } @existing_errorpages);;
	    }
	    elsif($res == -2) {
		$errorpages .= qq!* [[:$article]] (Template [[Mall:$tmpl_wous]], Error: contains sub-templates (not handled at the moment), Date: $datum\n! unless(grep { $_ eq $article } @existing_errorpages);
	    }

	    next;
	}


	$newtext =~ s/\}\}$// unless($text =~ /\}\}$/);
	if($newtext eq $text) {
	    print "-- No change detected, moving on\n";
	    next;
	}
	    
	print diff \$text, \$newtext;
	my $editsum = "\x{d6}vers\x{e4}tter k\x{e4}llmall: [[Mall:$tmpl_wous]]";
	
#	print "\nEdit? [Y/n] ";
#	my $input = <STDIN>;
#	chomp($input);
#	if($input !~ /^n/i) {
	    $bot->edit($article, $newtext, "$editsum");
#	}

	sleep 10;
    }


    if(defined $errorpages) {
	my $new_errorpage = $current_errorpage . "\n" . $errorpages;
	$bot->edit("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$param_target", $new_errorpage, "Uppdaterar resultat");
    }

    exit;

}


foreach my $pair (split(/\n/, $alltemplates)) {
    next if(!$pair);
    exit if($pair =~ /BOTSTOP/);
    my($originstr, $target) = split(/\ \-\>\ /, $pair);
    $target =~ s/\ *\[\[(mall\:|template\:)?([^\]]+)\]\]/$2/i;
    $originstr =~ s/^\ *\*\ *//;
    my @origins = map { s/\[\[(mall\:|template\:)?([^\]]+)\]\]/$2/i } split(/\,\ */, $originstr);
    my $enctext = Encode::encode("utf-8", $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Parametrar/" . $target . ".js"));
    my $settings = JSON::PP->new->utf8->decode($enctext);
    foreach my $origin (@{$settings->{templatename_en}}) {
	next if(!$origin);
	scan_errorpages($origin, $settings);
    }

    if(($param_onlytemplate && $param_onlytemplate eq $target) || !$param_onlytemplate) {
	scan_template($target, $settings, @origins);
    }
}

sub scan_template {
    my $target = shift;
    my $settings = shift;
    my @origins = @_;

    reconnect();
# https://sv.wikipedia.org/w/api.php?action=query&list=embeddedin&eititle=Template:Cite%20book&einamespace=0&eifilterredir=nonredirects
# select COUNT(*) FROM templatelinks WHERE tl_title like 'Cite_book';

    my $sth = $dbh->prepare(qq!SELECT MAX(rev_timestamp) AS rev_timestamp, page_title, page_id FROM revision LEFT JOIN page on page_id = rev_page WHERE rev_timestamp > ? AND page_namespace = ? GROUP BY page_id ORDER BY MAX(rev_timestamp) ASC LIMIT 5000!);
    my $sthtmpl = $dbh->prepare(qq!SELECT * FROM templatelinks WHERE tl_title LIKE ? AND tl_namespace = ? AND tl_from = ?!);
    
    my $sth_tssel = $dbhp->prepare(qq!SELECT MAX(timestamp) FROM translatetemplate WHERE template = ?!);

    my $sth_sel = $dbhp->prepare(qq!SELECT * FROM translatetemplate WHERE page_id = ? AND template LIKE ? AND error = ?!);
    my $sth_ins = $dbhp->prepare(qq!INSERT IGNORE INTO translatetemplate (page_id, template, timestamp, error) VALUES (?, ?, ?, ?)!);
    my $sth_upd = $dbhp->prepare(qq!UPDATE translatetemplate SET timestamp = ?, error = ? WHERE page_id = ? AND template LIKE ?!);

    my $errorpages;

    foreach my $origintemplate (@{$settings->{templatename_en}}) {
	$sth_tssel->execute($origintemplate);
	my $lastts = $sth_tssel->fetchrow_array() || 0;
	
	warn "$origintemplate - starting from TS: $lastts" if($debug);

	my $refs;
	$sth->execute($lastts, 0);
	while(my $refrev = $sth->fetchrow_hashref()) {
	    $sthtmpl->execute($origintemplate, 10, $refrev->{page_id});
	    if($sthtmpl->rows()) {
		push @{$refs}, $refrev;
	    }
	}

	my $tmpl_wous = $origintemplate;
	$tmpl_wous =~s/\_/\ /g;

	foreach my $ref (@{$refs}) {
	    reconnect();
#	    warn "sth sel: $ref->{page_id}, $origintemplate";
	    $sth_sel->execute($ref->{page_id}, $origintemplate, 0);
	    my $ref_tt = $sth_sel->fetchrow_hashref();
	    if(!$sth_sel->rows() || ($sth_sel->rows() && $ref->{rev_timestamp} > $ref_tt->{timestamp})) {
		my $text = $bot->get_text($ref->{page_title});
		my $orgtext = $text;
		my $newtext;
		if($text =~ /\{\{$tmpl_wous/i) {
		    print $ref->{page_title} . "\n";
		    my ($res, $newtext) = substitute($ref->{page_title}, $tmpl_wous, $settings, $text);
		    if($res < 0) {
			if($res == -1) {
			    $errorpages .= qq!* [[:$ref->{page_title}]] (Template: [[Mall:$tmpl_wous]], Error: Unmatched parameters, Parameters: ! . join(", ", @{$newtext}) . qq!, Date: $datum)\n!;
			}
			elsif($res == -2) {
			    $errorpages .= qq!* [[:$ref->{page_title}]] (Template [[Mall:$tmpl_wous]], Error: contains sub-templates (not handled at the moment), Date: $datum\n!;
			}

			if($sth_sel->rows()) {
                            $sth_upd->execute($ref->{rev_timestamp}, $res, $ref->{page_id}, $origintemplate);
                        }
                        else {
                            $sth_ins->execute($ref->{page_id}, $origintemplate, $ref->{rev_timestamp}, $res);
                        }

			next;
		    }

		    $newtext =~ s/\}\}$// unless($orgtext =~ /\}\}$/);
		    
		    if($orgtext eq $newtext) {
			$errorpages .= qq!* [[:$ref->{page_title}]] (Template: [[Mall:$tmpl_wous]], Error: Template match but no change made, Date: $datum)\n!;
			if($sth_sel->rows()) {
                            $sth_upd->execute($ref->{rev_timestamp}, -10, $ref->{page_id}, $origintemplate);
                        }
                        else {
                            $sth_ins->execute($ref->{page_id}, $origintemplate, $ref->{rev_timestamp}, -10);
                        }
			next;
		    }

		    my $colororgtext = $orgtext;
		    $colororgtext =~ s/(\{\{$tmpl_wous)/\e\[43m\e\[30m$1\e\[0m/gi;
		    
		    print diff \$colororgtext, \$newtext;
		    my $editsum = "\x{d6}vers\x{e4}tter k\x{e4}llmall: [[Mall:$tmpl_wous]]";
		    print "\n";
		    print ":: $editsum";

		    if(!$autoedit) {
			`printf '\a'`;
			print "\nEdit? [Y/n] ";
			my $input = <STDIN>;
			chomp($input);
			if($input !~ /^n/i) {
			    $bot->edit($ref->{page_title}, $newtext, "$editsum");
			    if($sth_sel->rows()) {
				$sth_upd->execute($ref->{rev_timestamp}, 0, $ref->{page_id}, $origintemplate);
			    }
			    else {
				$sth_ins->execute($ref->{page_id}, $origintemplate, $ref->{rev_timestamp}, 0);
			    }
			    
			    sleep 2;
			}
		    }
		    else {
			$bot->edit($ref->{page_title}, $newtext, "$editsum");
			if($sth_sel->rows()) {
			    $sth_upd->execute($ref->{rev_timestamp}, 0, $ref->{page_id}, $origintemplate);
			}
			else {
			    $sth_ins->execute($ref->{page_id}, $origintemplate, $ref->{rev_timestamp}, 0);
			}

			sleep 2;
		    }
			
		}
		else {
		    print "$ref->{page_title} ($ref->{page_id}) - No match\n";
		    if($sth_sel->rows()) {
			$sth_upd->execute($ref->{rev_timestamp}, 0, $ref->{page_id}, $origintemplate);
		    }
		    else {
			$sth_ins->execute($ref->{page_id}, $origintemplate, $ref->{rev_timestamp}, 0);
		    }
		}
	    }
	}
    }

    if(defined $errorpages) {
	my $current_errorpage = $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$settings->{templatename_sv}");
	$current_errorpage = "" if($current_errorpage eq "2");
	my $new_errorpage = $current_errorpage . "\n" . $errorpages;
	$bot->edit("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$settings->{templatename_sv}", $new_errorpage, "Uppdaterar resultat");
    }
}


sub scan_errorpages {
    my $tmpl = shift;
    my $settings = shift;

    my @fixedpages;

    my $tmpl_wous = $tmpl;
    $tmpl_wous =~ s/\_/\ /g;

    my $sth_tssel = $dbhp->prepare(qq!SELECT MAX(timestamp) FROM translatetemplate WHERE template = ?!);

    my $sth_sel = $dbhp->prepare(qq!SELECT * FROM translatetemplate WHERE template LIKE ? AND error < ?!);
    my $sth_upd = $dbhp->prepare(qq!UPDATE translatetemplate SET error = ? WHERE id = ?!);
    my $sth_del = $dbhp->prepare(qq!DELETE FROM translatetemplate WHERE page_id = ?!);

    my $sth_pagename = $dbh->prepare(qq!SELECT page_title FROM page WHERE page_id = ?!);


    my $text = $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$settings->{templatename_sv}");
    foreach my $row (split(/\n/, $text)) {
	$row =~ s/^\*\ \[\[\:([^\]]+)\].*/$1/g;
	warn $row;
	next if(!$row);
	my $page_title = $row;
	my $orgtext = $bot->get_text($page_title);
	my ($res, $newtext) = substitute($page_title, $tmpl_wous, $settings, $orgtext);
	
	if($res == -1) {
	    # still error, don't do anything.
	    print "$page_title is still in error. Faulty parameters: " . join(", ", @{$newtext}) . "\n";
	}
	elsif($res == -2) {
	    print "$page_title has sub-templates\n";
	}
	else {
	    print "Scaning errorpage: $page_title\n";
	    $newtext =~ s/\}\}$// unless($orgtext =~ /\}\}$/);
	    
	    if($orgtext eq $newtext) {
		print "$page_title hasn't changed.\n";
		return;
	    }
	    else {
		print diff \$orgtext, \$newtext;
		my $editsum = "\x{d6}vers\x{e4}tter k\x{e4}llmall: [[Mall:$tmpl_wous]]";
		print "\n";
		print ":: $editsum";
		
		if(!$autoedit) {
		    print "\nEdit? [Y/n] ";
		    my $input = <STDIN>;
		    chomp($input);
		    if($input !~ /^n/i) {
			$bot->edit($page_title, $newtext, "$editsum");
			# $sth_upd->execute(0, $ref->{id});
			push @fixedpages, $page_title;
		    }
		}
		else {
		    $bot->edit($page_title, $newtext, "$editsum");
		    # $sth_upd->execute(0, $ref->{id});
		    push @fixedpages, $page_title;
		}
	    }
	}
    }		

    if(defined $fixedpages[0]) {
	my $newtext;
	my $text = $bot->get_text("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$settings->{templatename_sv}");
	foreach my $row (split(/\n/, $text)) {
	    $newtext .= $row . "\n" unless(grep { $row =~ /\[\[\:$_\]\]/ && $row =~ /\[\[Mall\:$tmpl_wous\]\]/ } @fixedpages);
	}
	$bot->edit("User:Fluffbot/K\x{e4}llmalls\x{f6}vers\x{e4}ttning/Resultat/$settings->{templatename_sv}", $newtext, "Rensar resultatlista");
    }
}


sub substitute {
    my $article = shift;
    my $tmpl_wous = shift;
    my $settings = shift;
    my $text = shift;

    my $newtext = "";

    my @parts = split(/\}\}/, $text);

    my @errorparams;

    my $skippartcounter = 0;

    for(my $i = 0; $i < scalar @parts; $i++) {
	next if(!defined $parts[$i]);
	my $part = $parts[$i];
	warn "This is part $i. Skipcounter at $skippartcounter: $part";
	if($skippartcounter > 0) {
	    $skippartcounter--;
#	    next;
	}

	my ($prepart, $tmplpart) = split(/\{\{$tmpl_wous\s*\|/i, $part);
	if(!defined $tmplpart) {
	    $newtext .= $part . qq!}}!;
	    next;
	}

	if($tmplpart =~ /\{\{/ >= 1) {
	    # template within a template.

	    return -2, "Template within a template";

	    while($tmplpart =~ /\{\{/ > $tmplpart =~ /\}\}/) {

		if($skippartcounter == 0) {
		    my ($citetmpl, $subtmpl) = split(/\{\{/, $tmplpart, 2);
		    $subtmpl =~ s/\|/\-\-\^\-\-/g;
		    $subtmpl =~ s/\=/\-\-\_\-\-/g;
		    $tmplpart = $citetmpl . "{{" . $subtmpl . "}}";
		}

		# now the subtemplate is done, but probably not the original template. Do another add but don't escape the |
		if(defined $parts[$i + $skippartcounter + 1]) {
		    $skippartcounter++;
		    my $newpart = $parts[$i + $skippartcounter];
		    my ($prepart, $subtmpl) = split(/\{\{/, $newpart, 2);

		    if(defined $subtmpl) {
			$subtmpl =~ s/\|/\-\-\^\-\-/g;
			$subtmpl =~ s/\=/\-\-\_\-\-/g;

			$tmplpart .= $prepart . "{{" . $subtmpl;
		    }
		    else {
			$tmplpart .= $prepart . qq!}}!;
		    }
		}
	    }
	}

	$newtext .= $prepart;
	$newtext .= qq!{{! . $settings->{templatename_sv} . qq!|!;

	# Protect ordinary wikilinks
	$tmplpart =~ s/\[\[([^\||^\]]+)\|([^\]]+)\]\]/\[\[$1\-\-\^\-\-$2\]\]/g;

	foreach my $pair (split(/\|/, $tmplpart)) {
	    my ($key, $val) = split(/\s*\=/, $pair, 2);
	    print "!! $key !=! $val\n";
	    $key =~ s/^\s*//g;
	    if(grep { $_ eq $key } keys %{$settings->{parameters}}) {
		$newtext .= $settings->{parameters}->{$key} . "=" . $val . "|";
	    }
	    elsif((defined $settings->{parameters_ignore} && grep { $_ eq $key } @{$settings->{parameters_ignore}})
		  || $settings->{default_parameter_action} eq "ignore") {
		$newtext .= $pair . "|";
	    }
	    elsif((defined $settings->{parameters_delete} && grep { $_ eq $key } @{$settings->{parameters_delete}})
		  || $settings->{default_parameter_action} eq "delete") {
		# well. do nothing.
	    }
	    else {
		$key =~ s/\n//g;
		warn "Not able to translate parameter: $key, skipping";
		push @errorparams, $key;
	    }
	}
	$newtext =~ s/\|$//;
	$newtext =~ s/\-\-\^\-\-/\|/g;
	$newtext =~ s/\-\-\_\-\-/\=/g;
	$newtext =~ s/\|$//;
	$newtext .= qq!}}!;
    }

    if(defined $errorparams[0]) {
	return -1, \@errorparams;
    }
    else {
	return 1, $newtext;
    }
}
