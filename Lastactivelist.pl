#!/usr/bin/perl
$| = 1;


use lib "/data/project/perfectbot/Fluffbot/mediawikiapi/lib";
use strict;
use DBI;
use MediaWiki::API;
use Encode;
use Data::Dumper;
use Getopt::Std;
use Text::Diff;
use Date::Format;

# lal - last active list
# Fluff@svwp.

my $bot = MediaWiki::API->new({ api_url => "https://sv.wikipedia.org/w/api.php" });

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login({ lgname => "Fluffbot", lgpassword => $pwd });

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;hostname=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $today = time2str("%Y-%m-%d %H:%M:%S %Z", time, "UTC");

my %u;
my $page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Robotar|bot-status]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
	     $page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;


my $groupsth = $dbh->prepare(qq!SELECT * from user u LEFT JOIN user_groups ug ON ug.ug_user = u.user_id WHERE ug.ug_group = ?!);
my $lastrevsth = $dbh->prepare(qq!SELECT rev_timestamp FROM revision r LEFT JOIN actor a on a.actor_id = r.rev_actor WHERE a.actor_user = ? ORDER BY r.rev_timestamp DESC LIMIT 1!);
$groupsth->execute("bot");
while($_ = $groupsth->fetchrow_hashref()) {

    $lastrevsth->execute($_->{user_id});
    
    my $laldate = $lastrevsth->fetchrow_array();
    $laldate =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$1-$2-$3\ $4:$5:$6/;

    my $count = $_->{user_editcount};
    $page .= qq!|-\n| [[User:$_->{user_name}|$_->{user_name}]] ([[Special:Bidrag/$_->{user_name}|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_->{user_name} - $laldate\n";

}

$page .= qq!\n|}!;

$bot->edit({
    action => "edit",
    bot => 1,
    title => "User:Fluffbot/LAL-Bot", 
    text => Encode::decode("utf-8", $page), 
    summary => "Uppdaterar listan"
});

# Rollbacker

$page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Tillbakarullning|tillbakarullar-status]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
	     $page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;

$groupsth->execute("rollbacker");

while($_ = $groupsth->fetchrow_hashref()) {

    $lastrevsth->execute($_->{user_id});
    my $laldate = $lastrevsth->fetchrow_array();
    $laldate =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$1-$2-$3\ $4:$5:$6/;
#    $laldate =~ s/Z/\ UTC/;
    my $count = $_->{user_editcount};
    $page .= qq!|-\n| [[User:$_->{user_name}|$_->{user_name}]] ([[Special:Bidrag/$_->{user_name}|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_->{user_name} - $laldate\n";

}

$page .= qq!\n|}!;
$bot->edit({
    action => "edit",
    bot => 1,
    title => "User:Fluffbot/LAL-Tillbakarullare", 
    text => Encode::decode("utf-8", $page), 
    summary => "Uppdaterar listan"
});

# Autopatrolled

$page = qq!Detta &auml;r en lista &ouml;ver konton p&aring; svwp som har [[WP:Projekt patrullering av nya sidor|autopatrullstatus]] och n&auml;r de senast var aktiva p&aring; svwp.!;
$page .= qq! Listan uppdaterades senast: '''$today'''.!;
$page .= qq!\n\n!;
$page .= qq!{|class="wikitable sortable"\n!;
$page .= qq<! Anv&auml;ndare !! Senaste redigering !! Antal redigeringar\n>;

$groupsth->execute("autopatrolled");

while($_ = $groupsth->fetchrow_hashref()) {

    $lastrevsth->execute($_->{user_id});
    
    my $laldate = $lastrevsth->fetchrow_array();
    $laldate =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$1-$2-$3\ $4:$5:$6/;
#    $laldate =~ s/Z/\ UTC/;
    my $count = $_->{user_editcount};
    $page .= qq!|-\n| [[User:$_->{user_name}|$_->{user_name}]] ([[Special:Bidrag/$_->{user_name}|bidrag]]) || $laldate || $count\n!;
    print "Processing user $_->{user_name} - $laldate\n";

}

$page .= qq!\n|}!;
$bot->edit({
    action => "edit",
    bot => 1,
    title => "User:Fluffbot/LAL-Autopatrullerade", 
    text => Encode::decode("utf-8", $page), 
    summary => "Uppdaterar listan"
});


