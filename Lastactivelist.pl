#!/usr/bin/perl
$| = 1;


use lib "/data/project/perfectbot/Fluffbot/perlwikipedia-fluff/lib";
use strict;
use Perlwikipedia;
use Encode;
use Data::Dumper;
use Getopt::Std;
use Text::Diff;
use Date::Format;

# lal - last active list
# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");

$bot->{debug} = 1;
print qq!Starting up Fluffbot.\n\n!;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $today = time2str("%Y-%m-%d %H:%M:%S %Z", time, "UTC");

my %u;
my $page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Robotar|bot-status]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
	     $page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;

foreach($bot->get_allusers("500", "bot")) {
    my $laldate = $bot->last_active($_);
    $laldate =~ s/T.*//;

    my $count = $bot->count_contributions($_);
    $page .= qq!|-\n| [[User:$_|$_]] ([[Special:Bidrag/$_|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_ - $laldate\n";
    sleep 1;
}

$page .= qq!\n|}!;

$bot->edit("User:Fluffbot/LAL-Bot", $page, "Uppdaterar listan");

# Rollbacker

$page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Tillbakarullning|tillbakarullar-status]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
	     $page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;

foreach($bot->get_allusers("500", "rollbacker")) {
    my $laldate = $bot->last_active($_);
    $laldate =~ s/T.*//;
#    $laldate =~ s/Z/\ UTC/;
    my $count = $bot->count_contributions($_);
    $page .= qq!|-\n| [[User:$_|$_]] ([[Special:Bidrag/$_|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_ - $laldate\n";
    sleep 1;
}

$page .= qq!\n|}!;
$bot->edit("User:Fluffbot/LAL-Tillbakarullare", $page, "Uppdaterar listan");

# Autopatrolled

$page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Projekt patrullering av nya sidor|autopatrullstatus]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
$page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;

foreach($bot->get_allusers("500", "autopatrolled")) {
    my $laldate = $bot->last_active($_);
    $laldate =~ s/T.*//;
#    $laldate =~ s/Z/\ UTC/;
    my $count = $bot->count_contributions($_);
    $page .= qq!|-\n| [[User:$_|$_]] ([[Special:Bidrag/$_|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_ - $laldate\n";
    sleep 1;
}

$page .= qq!\n|}!;
$bot->edit("User:Fluffbot/LAL-Autopatrullerade", $page, "Uppdaterar listan");
