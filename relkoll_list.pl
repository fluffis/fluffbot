#!/usr/bin/perl

# Generate list of articles on relkoll.
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

use strict;

use lib "/data/project/perfectbot/Fluffbot/mediawikiapi/lib";
use MediaWiki::API;
use Encode;
use DateTime;
use Data::Dumper;

## Kontrollerar samtliga artiklar i Kategori:Relevanskontroll och listar
# * Artikelns namn
# * Senaste redigering
# * När artikeln (troligtvis) blev relevanskontrollmärkt.
# Fluff@svwp.

my $bot = MediaWiki::API->new({ api_url => "https://sv.wikipedia.org/w/api.php" });

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login({ lgname => "Fluffbot", lgpassword => $pwd });

my $out;
my $antart = 0;

my @catpages = get_all_pages("Kategori:Relevanskontroll");
foreach my $catpage (@catpages) {
    $catpage =~ s/amp;//g;
    next if($catpage =~ /^(Kategori\:|Wikipedia\:|Wikipediadiskussion\:|Mall\:Rel|Malldiskussion\:Relevanskontroll)/);
    print "Processing $catpage\n";
    $antart++;

    my $pagerevs = $bot->api({
	action => 'query',
	prop => 'revisions',
	titles => $catpage,
	rvprop => "ids|timestamp|user|comment",
	rvlimit => 25
			     });
    my @pageids = keys %{$pagerevs->{query}->{pages}};
    foreach my $ref (@{$pagerevs->{query}->{pages}->{$pageids[0]}->{revisions}}) {
	my $apage = $bot->get_page({ title => $catpage, revid => $ref->{revid} });
	my $atext = $apage->{'*'};
	($ref->{timestamp_date}, $ref->{timestamp_time}) = split(/T/, $ref->{timestamp});
	if(!defined $out->{$catpage}{'lastedit'}) {
	    # Detta är senaste editen, alltså sätter vi tid och id.
	    $out->{$catpage}{'lastedit'} = "$ref->{timestamp_date}&nbsp;$ref->{timestamp_time}";
	    $out->{$catpage}{'lasteditid'} = $ref->{revid};       

	    # Kolla om den senaste versionen är anmäld till sffr:
	    $out->{$catpage}{'sffr'} = $atext =~ m/\{\{sffr\}\}/i ? 1 : 0;
	}

	if($atext =~ m/\{\{relevanskontroll/i || $atext =~ m/\{\{brist/i  || $atext =~ m/\{\{rk\|/i || $atext =~ m/\{\{rel\|/i) {
	    $out->{$catpage}{'templateinserted'} = "$ref->{timestamp_date}&nbsp;$ref->{timestamp_time}";
	    $out->{$catpage}{'templateinsertedid'} = $ref->{revid};
	    $out->{$catpage}{'templaterevs'} = -1 if(!defined $out->{$catpage}{'templaterevs'});
	    $out->{$catpage}{'templaterevs'} += 1;
	    sleep 1;
	    next;
	}
	else {
	    last;
	}
	print "Done with $catpage\n";
	sleep 5;
    }
}

print "Antal artiklar kontrollerade: $antart\n";

# Eventuellt visa diff mellan senast ändrad och när en artikel blev relkollad.

my $edittext = qq!'''Detta &auml;r en automatiskt genererad lista &ouml;ver alla artiklar som ing&aring;r i kategorierna [[:Kategori:Relevanskontroll]]. Listan genereras en g&aring;ng om dagen av [[User:Fluffbot|Fluffbot]]. Listan uppdaterades senast: !;
my $dt = DateTime->now;
$edittext .= $dt->ymd . " " . $dt->hms;
$edittext .= qq! UTC'''\n\nListan inneh&aring;ller $antart artiklar\n\n----\n!;

$edittext .= qq!{|class="wikitable sortable"\n|- bgcolor="#CCCCCC"\n!;
$edittext .= "! Artikel || Senast redigerad || Anm&auml;ld f&ouml;r relkoll<ref>Roboten s&ouml;ker igenom de senaste 25 redigeringarna.</ref> || Efter relkoll || SFFR \n|-\n";

foreach(sort {$out->{$a}{lastedit} <=> $out->{$b}{lastedit}} keys %{$out}) {
    my $artwus = $_;
    $artwus =~ s/\ /\_/g;
    $edittext .= qq!| [[$_]] ([[Talk:$_|disk]]) || [http://sv.wikipedia.org/w/index.php?title=$artwus&oldid=$out->{$_}{'lasteditid'} $out->{$_}{'lastedit'}] || !;
    if($out->{$_}{'templateinserted'}) {
	$edittext .= qq![http://sv.wikipedia.org/w/index.php?title=$artwus&oldid=$out->{$_}{templateinsertedid} $out->{$_}{templateinserted}]!;
    }
    else {
	$edittext .= qq!> 25 redigeringar!;
    }
    $edittext .= qq! || !;
    $edittext .= $out->{$_}{'templaterevs'} ? $out->{$_}{'templaterevs'} : ($out->{$_}->{'templateinserted'} ? "0" : "> 25");
    $edittext .= $out->{$_}{'templaterevs'} == 1 ? qq! redigering! : qq! redigeringar!;

    if($out->{$_}{sffr}) {
	$edittext .= qq! || [[WP:Sidor f! . chr(246) . qq!reslagna f! . chr(246) . qq!r radering/$_|Ja]] !;
    }
    else {
	$edittext .= qq! || Nej !;
    }
    $edittext .= qq!\n|-\n!;
}
$edittext .= qq!|}\n!;

$edittext .= qq!\n\n==Not==\n<references/>\n!;

$bot->edit({
    action => "edit",
    bot => 1,
    minor => 1,
    title => "Wikipedia:Projekt relevanskontroll/Alla artiklar i datumordning", 
    text => $edittext, 
    summary => "Uppdaterar listan"
});
open(LOGF, ">>relkoll_history.csv");
print LOGF $dt->ymd . ";$antart\n";
close(LOGF);

sub get_all_pages {
    my $category = shift;

    my $res = $bot->list({
	action => 'query',
	list => 'categorymembers',
	cmtitle => $category,
	cmlimit => 500
			 });
    my @pages = map { $_->{'title'} } grep { $_->{ns} != 14 } @$res;
    push @pages, get_all_pages($_) foreach(map { $_->{title} } grep { $_->{ns} == 14 } @$res);
	
    return @pages;
}
