#!/usr/bin/perl

# Lists IP addresses that are blocked but the block allows accounts
# to be created through the block.
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

my $sth = $dbh->prepare(qq!SELECT ipb_address, DATE_FORMAT(ipb_timestamp, "%Y-%m-%d") AS ipb_timestamp, ipb_reason, ipb_by_text, DATE_FORMAT(ipb_expiry, "%Y-%m-%d") AS ipb_expiry FROM ipblocks WHERE ipb_user = 0 and ipb_create_account = 0 and DATE_FORMAT(ipb_expiry, "%Y-%m-%d %H:%i:%s") > NOW() ORDER BY ipb_range_start!);
$sth->execute();

# Samla in alla, ordna per nät
# 

my $pageh = qq!__NOTOC__\n\nDetta är en lista över blockerade IP-adresser som tillåts skapa konton. Listan uppdaterades senast: !;
$pageh .= getwikidate();
$pageh .= qq!, förändringar i blockeringar reflekteras inte förrän listan uppdateras.\n\n!;
$pageh .= qq!{| class="wikitable sortable"\n!;
$pageh .= "!Adress/Range || Utförd || Upphör || Motivering || Blockerad av \n";
$pageh .= "|-\n";

while(my $ref = $sth->fetchrow_hashref()) {

    $pageh .= "| [[User talk:$ref->{ipb_address}|$ref->{ipb_address}]] ([[Special:Bidrag/$ref->{ipb_address}|b]]) || $ref->{ipb_timestamp} || $ref->{ipb_expiry} || <small>$ref->{ipb_reason}</small> || [[User:$ref->{ipb_by_text}|$ref->{ipb_by_text}]] \n";
    $pageh .= "|-\n";
}

$pageh .= "|}\n";

$bot->edit("User:Fluffbot/Lista_\x{f6}ver_blockerade_adresser_som_till\x{e5}ts_skapa_konton", Encode::decode("utf-8", $pageh), "Uppdaterar listan");

sub byusername {
    my $aver = ip_get_version($a) || 8;
    my $bver = ip_get_version($b) || 8;
    my $at = $aver < 8 ? "$aver|" . ip_iptobin($a, $aver) : "8|$a";
    my $bt = $bver < 8 ? "$bver|" . ip_iptobin($b, $bver) : "8|$b";

    return $at cmp $bt;
}

sub bynetwork {
    my $aver;
    my $bver;
    if($a =~ /\ \-\ /) {
	$aver = network4_iptobin($a);
    }
    else {
	$aver = $a;
    }

    if($b =~ /\ \-\ /) {
	$bver = network4_iptobin($b);
    }
    else {
	$bver = $b;
    }

    return $aver cmp $bver;
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

sub network4_iptobin {
    my $adrstr = shift;
    my ($start, $stop) = split(/\ \-\ /, $adrstr);

    return ip_iptobin($start, 4) . " - " . ip_iptobin($stop, 4);
}

sub ip_iptohex {
    my $address = shift;
    my $hex;

    foreach(split(/\./, $address)) {
	$hex .= sprintf("%02x", $_);
    }

}
