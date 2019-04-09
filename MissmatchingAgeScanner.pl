#!/usr/bin/perl

# Fluffbot listing people with missmatching body vs category when enumerating
# their year of birth and year of death.
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

use strict;
use warnings;

use XML::LibXML::Reader;
use utf8;
use Data::Dumper;
use Digest::MD5 qw(md5_base64);
use Encode qw(encode_utf8);
use MediaWiki::API;

require '/data/project/perfectbot/Fluffbot/common.pl';

my $bot = MediaWiki::API->new();
$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login({ lgname => "Fluffbot", lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

my $text_falsepos_org_page = $bot->get_page({title => "User:Fluffbot/Misstänkt_felaktigt_födelse_eller_dödsår/Falska_träffar"});
my $text_falsepos_org = $text_falsepos_org_page->{'*'};
my $text_falsepos;
my $text_falsepos_new;
($text_falsepos_new, $text_falsepos) = split(/\<\!\-\-\ MARK\ \-\-\>/, $text_falsepos_org);


my %falsepos;
foreach my $row (split(/\n/, $text_falsepos)) {
	if($row =~ /^\#\ * \[\[([^\||^\]]+)\]\]\ *([^\ ]{24})/) {
		$falsepos{$1} = $2;
	}
}

my $r = XML::LibXML::Reader->new({FD => fileno(STDIN), schema => 'http://www.mediawiki.org/xml/export-0.10/'});

my $pageout = "";
$pageout .= qq!Denna sida är skapad utifrån databasdumpen som togs den ! . getwikidate() . qq!, redigeringar efter detta datum reflekteras inte i denna tabell.\n\n!;

$pageout .= qq!Roboten försöker identifiera vilket år som anges som födelse- respektive dödsår i artikelns brödtext och jämför sedan med kategoriseringen i Kategori:Födda och Kategori:Avlidna. Om detta inte stämmer överens så listas personen i tabellen nedan. Observera att identifieringen av årtal i brödtexten är svår och kan ge en hel del felaktiga indikationer.\n\n!;

$pageout .= qq!{|class="wikitable"\n!;
$pageout .= "! Artikel || Född (artikeltext) || F. år text || F. år kat || Avliden (artikeltext) || D. år text || D. år kat\n";
$pageout .= "|-\n";

my $c = 0;
my $f = 0;
my @articlerows;
while($r->read()) {

    if($r->name() eq "page") {
	$f++ if(processPage($r));
	
	$c++;
	warn "$c pages processed, $f suspects found." if($c % 10000 == 0);
    }
}
$r->close();

foreach my $row (sort @articlerows) {
    $pageout .= $row . "\n";
}

$pageout .= "|}\n";

$bot->login({ lgname => "Fluffbot", lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");
$bot->edit({
    action => 'edit',
    title => "User:Fluffbot/Misstänkt_felaktigt_födelse_eller_dödsår",
    text => $pageout, 
    summary => "Uppdaterar lista"
}) || die("$bot->{error}->{code}: $bot->{error}->{details}");


$text_falsepos_new .= "<!-- MARK -->\n";
foreach my $row (split(/\n/, $text_falsepos)) {
	if($row =~ /^\#\ * \[\[([^\||^\]]+)\]\]\ *([^\ ]{24})/) {
		if(exists $falsepos{$1}) {
			$text_falsepos_new .= $row . "\n";
		}
	}
}

$bot->edit({
    action => 'edit',
    title => "User:Fluffbot/Misstänkt_felaktigt_födelse_eller_dödsår/Falska_träffar", 
    text => $text_falsepos_new, 
    summary => "Tar bort falska träffar där checksum har ändrats."
}) || die("$bot->{error}->{code}: $bot->{error}->{details}");




#####################################################
sub processPage{
	my $r = shift;
	
	my $title;
	my $ns;
	my $pageid;
	my $revid;
	my $text;
	
	if($r->nextElement('title')) {
		$title = $r->readInnerXml();
    }
	
	if($r->nextElement('ns')) {
		$ns = $r->readInnerXml();
	}
	
	if($r->nextElement('id')) {
		$pageid = $r->readInnerXml();
	}
	
	if($r->nextElement('revision')) {
		($revid, $text) = processRevision($r);
	}
	
	my $res = 0;
	if(defined $ns) {
		$res = scan($pageid, $revid, $ns, $title, $text);
	}
	
	return $res;
	
}


sub processRevision {

	my $r = shift;
	
	my $revid;
	my $text;
	
	if($r->nextElement('id')) {
		$revid = $r->readInnerXml();
	}
	
	if($r->nextElement('text')) {
		$text = $r->readInnerXml();
	}
	
	return $revid, $text;
}

sub scan {
	my $pageid = shift;
	my $revid = shift;
	my $ns = shift;
	my $title = shift;
	my $text = shift;

	return 0 if($ns != 0);
	
	return 0 if($text !~ /\[\[kategori\:\ *(M\x{e4}n|Kvinnor)(\||\])/i);
	
	$text = removeTemplates($text);
	
	my($textborn, $katborn, $textdead, $katdead);
	$textborn = $katborn = $textdead = $katdead = 0;
	my $borncontext = "";
	my $deadcontext = "";
	
	if($text =~ /(.{0,20}(?<!\:)(född\ *(den)?\ *(?:(?!\d\d\d\d).){0,60}(\d{4}).{0,20}))/i) {
		$textborn = $4;
		$borncontext = $1;
	}

	$katborn = $2 if($text =~ /\[\[kategori\:\ *F\x{f6}dda(\ |\_)(\d{4})(\||\]|\ )/i);
	
	if($text =~ /(.{0,20}(?<!\{)(avliden|avled|död)\b(?:(?!\d\d\d\d).){0,40}(\d{4}).{0,20})/i) {
		$textdead = $3;
		$deadcontext = $1;
	}
	
	$katdead = $2 if($text =~ /\[\[kategori\:\ *Avlidna(\ |\_)(\d{4})(\||\]|\ )/i);
	
	
	return 0 if(($textborn == $katborn && $textdead == $katdead) ||
			$textborn < 1000 ||
			$textdead < 1000 ||
			$katborn < 1000 ||
			$katdead < 1000);
	
	my $titlewus = $title;
	$titlewus =~ s/\ /\_/g;

	my $digest = getChecksum($title, $borncontext, $katborn, $deadcontext, $katdead);
	
	if(exists $falsepos{$title}) {
		if($falsepos{$title} eq $digest) {
			return 0;
		}
		else {
			# New checksum, remove from false pos!
			delete $falsepos{$title};
		}
	}
	
	my $bornstyle = "";
	$bornstyle = qq!style="color:#C70039"! if($textborn != $katborn);
	my $deadstyle = "";
	$deadstyle = qq!style="color:#C70039"! if($textdead != $katdead);
	
	push @articlerows, qq!| [[$title]] <small>$digest</small>\n|| <nowiki>$borncontext</nowiki>\n|$bornstyle| $textborn\n|$bornstyle| $katborn\n|| <nowiki>$deadcontext</nowiki>\n|$deadstyle| $textdead\n|$deadstyle| $katdead\n|-\n!;
	
	return 1;
}

sub removeTemplates {
	my $text = shift;
	
	while($text =~ /(\{\{(?:(?!(\}\}|\{\{)).)*\}\})/s) {
		$text =~ s/(\{\{(?:(?!(\}\}|\{\{)).)*\}\})//s;
	}
	$text =~ s/<ref(?:(?!(<\/ref>)).)*<\/ref>//sg;
	$text =~ s/<ref(?:(?!(\/>)).)*\/>//sg;
	
	return $text;
}

sub getChecksum {

	my $md5 = Digest::MD5->new;
	foreach my $s (@_) {
		$md5->add(encode_utf8($s));
	
	}

	my $digest = $md5->b64digest;
	while(length($digest) % 4) {
		$digest .= '=';
	}
	return $digest;
}
