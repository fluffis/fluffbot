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

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});


my $ua = LWP::UserAgent->new();
my $req = $ua->get("https://sv.wikipedia.org/w/index.php?title=Anv%C3%A4ndare:Fluffbot/Lista_över_läsårsblockerade/config.js&action=raw");
my $res = $req->decoded_content();

my $templates = decode_json(Encode::encode("utf-8", $res));

my @allips;
foreach my $templ (@{$templates->{templates}}) {

    # To retrieve from getusers, we need _
    # To print, we need space
    $templ =~ s/\ /\_/g;
    my @lip = map { $_->{title} =~ s/Anv\x{e4}ndardiskussion\://; $_->{title}; } $bot->what_links_here_opts("Mall:$templ", "&namespace=3&hidelinks=1");
    foreach my $ip (@lip) {
	push @allips, $ip unless(grep {$ip eq $_ } @allips);
    }
}
my $networkpages;
foreach(sort byusername @allips) {
    my $ippage = "";
    $ippage .= "==== [[User:$_|$_]] ====\n";
    $ippage .= "* [[User talk:$_|Diskussion]]\n";
    $ippage .= "* [[Special:Bidrag/$_|Bidrag]]\n";

    my $talkpage = Encode::encode("utf-8", $bot->get_text("User talk:$_"));
    if($talkpage =~ /\{\{ip\|([^\}]+)\}\}/i) {
	$ippage .= "* IP-mall: $1\n";
    }
    else {
	$ippage .= "* IP-mall: Saknas\n";
    }
    
    my @descr;
    my $inetnum;
    foreach(split(/\n/, `whois $_`)) {
        /^([^\:]+)\:\ *(.*)/;
	if($1 eq "descr") {
	    push @descr, Encode::encode("utf-8", $2);
	}
	if($1 eq "inetnum") {
	    $inetnum = $2;
	}
    }
    $ippage .= "* WHOIS descr: " . join(", ", @descr) . "\n";

    push @{$networkpages->{$inetnum}}, $ippage;

}

my $pageh = qq!__NOTOC__\n\nDetta är en lista över användarsidor som har en av följande mallar: {{mall|Skolblockering}}, {{mall|Läsårsblockering}} eller {{mall|Lb}}. Listan uppdaterades senast: !;
$pageh .= getwikidate();
$pageh .= qq!\n\n!;

foreach my $net (sort bynetwork keys %{$networkpages}) {
    $pageh .= "=== $net ===\n";
    foreach(@{$networkpages->{$net}}) {
	$pageh .= $_;
    }
}

$bot->edit("User:Fluffbot/Lista_\x{f6}ver_l\x{e4}s\x{e5}rsblockerade", Encode::decode("utf-8", $pageh), "Uppdaterar listan");

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
