#!/usr/bin/perl

# Lists users who's talk-pages contain a template that indicate an active block
# but the block has expired (the user is no longer blocked.)
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

use strict;
use warnings;
use Perlwikipedia;
use Encode;
use Data::Dumper;
use LWP::UserAgent;
use DBI;
use JSON::XS;

binmode STDOUT, ":utf8";

require 'common.pl';

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");

#$bot->{debug} = 1;
print qq!Starting up Fluffbot.\n\n!;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});


my $ua = LWP::UserAgent->new();
my $req = $ua->get("https://sv.wikipedia.org/w/index.php?title=Anv%C3%A4ndare:Fluffbot/Users_with_blocking_templates/config.js&action=raw");
my $res = $req->decoded_content();

my $templates = decode_json(Encode::encode("utf-8", $res));

my $page;
my $simplepage;
foreach my $templ (@{$templates->{templates}}) {

    my $tmplprint = $templ;
    # To retrieve from getusers, we need _
    # To print, we need space
    $templ =~ s/\ /\_/g;
    $tmplprint =~ s/\_/\ /;

    $page .= qq!== $tmplprint ==\n!;
    $simplepage .= qq!== $tmplprint ==\n!;

    foreach(map { Encode::decode("utf-8", $_) } sort byusername getusers($templ)) {

	$page .= "# [[User:$_|$_]] ([[User talk:$_|diskussion]] {{,}} [[Special:Bidrag/$_|bidrag]] {{,}} [[Special:Blockera/$_|blockera]]) $_\n";
	$simplepage .= "$_\n";
    }
}

my $pageh = qq!Detta &auml;r en lista &ouml;ver anv&auml;ndare vars anv&auml;ndardiskussionssidor inneh&auml;ller en mall som indikerar att de &auml;r blockerade fast att det inte l&auml;ngre ligger n&aring;gon blockering. Listan uppdaterades senast: !;
$pageh .= getwikidate();
$pageh .= qq!\n\n!;
$pageh .= $page;

$bot->edit("User:Fluffbot/Users with blocking templates", $pageh, "Uppdaterar listan");
open(PO, ">expiredblockswithtemplates.txt");
print PO "Last run: " . getwikidate() . "\n\n";
print PO $simplepage;
close(PO);

sub getusers {
    my $target = shift;

    warn "getusers() for $target";

    my $sth = $dbh->prepare(qq!SELECT ipb_id, page_title FROM templatelinks LEFT JOIN page ON page_id = tl_from LEFT JOIN ipblocks ON REPLACE(ipb_address, " ", "_") = page_title WHERE tl_namespace = 10 AND tl_title LIKE ? AND tl_from_namespace = 3 ORDER BY page_title ASC!);
    $sth->execute($target);

    my @tout;

    if($sth->rows()) {
	while(my ($id, $user) = $sth->fetchrow_array()) {
	    push @tout, $user if(!$id);
	}
    }

    return @tout;
}


sub byusername {
    my $aver = ip_get_version($a) || 8;
    my $bver = ip_get_version($b) || 8;
    my $at = $aver < 8 ? "$aver|" . ip_iptobin($a, $aver) : "8|$a";
    my $bt = $bver < 8 ? "$bver|" . ip_iptobin($b, $bver) : "8|$b";

    return $at cmp $bt;
}

sub ip_get_version {
    my $address = shift;

    if($address =~ /^(([01]?\d\d?|2[0-4]\d|25[0-5])\.){3}([01]?\d\d?|2[0-4]\d|25[0-5])$/) {
	return 4;
    }
    elsif($address =~ /^([0-9a-f]{1,4}:){7}([0-9a-f]){1,4}$/) {
	return 6;
    }
    else {
	return undef;
    }

}

sub ip_iptobin {
    my $address = shift;
    my $version = shift;

    if ($version == 4) {
        return unpack('B32', pack('C4C4C4C4', split(/\./, $address)));
    }

    $address =~ s/://g;

    if(length($address) == 32) {
	return unpack('B128', pack('H32', $address));
    }
}
