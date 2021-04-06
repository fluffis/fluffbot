#!/usr/bin/perl

use strict;

use lib "/data/project/perfectbot/Fluffbot/perlwikipedia-fluff/lib";
use Perlwikipedia;
use Encode;
use DateTime;
use Data::Dumper;

## Kontrollerar samtliga artiklar i Kategori:Relevanskontroll och listar
# * Artikelns namn
# * Senaste redigering
# * När artikeln (troligtvis) blev relevanskontrollmärkt.
# Fluff@svwp.

my $bot = Perlwikipedia->new("Fluffbot");
$bot->{debug} = 1;
$bot->set_wiki("sv.wikipedia.org", "w");

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $out;
my $antart = 0;
foreach my $catpage ($bot->get_all_pages_in_category("Kategori:Relevanskontroll")) {
    $catpage =~ s/amp;//g;
    next if($catpage =~ /^(Kategori\:|Wikipedia\:|Wikipediadiskussion\:|Mall\:Rel|Malldiskussion\:Relevanskontroll)/);
    print "Processing $catpage\n";
    $antart++;
    foreach my $ref ($bot->get_history($catpage, 25)) {
	my $atext = $bot->get_text($catpage, $ref->{revid});
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

$bot->edit("Wikipedia:Projekt relevanskontroll/Alla artiklar i datumordning", $edittext, "Uppdaterar listan");
open(LOGF, ">>relkoll_history.csv");
print LOGF $dt->ymd . ";$antart\n";
close(LOGF);
