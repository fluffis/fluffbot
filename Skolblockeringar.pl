#!/usr/bin/perl

# List users with template {{läsårsblockering}}
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
use Time::Piece;
use Time::Seconds;
use DBI;
use JSON::XS;

binmode STDOUT, ":utf8";

require '/data/project/perfectbot/Fluffbot/common.pl';

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

my $sth = $dbh->prepare(qq!SELECT TIMESTAMPDIFF(SECOND, ?, ?)!);
my $networkpages;
foreach(sort byusername @allips) {
    my $ippage = "|-\n";
    $ippage .= "| [[User:$_|$_]] ||";
    $ippage .= " [[User talk:$_|Diskussion]] ||";
    $ippage .= " [[Special:Bidrag/$_|Bidrag]] ||";

    my $talkpage = Encode::encode("utf-8", $bot->get_text("User talk:$_"));
    if($talkpage =~ /\{\{ip\|([^\}]+)\}\}/i) {
	$ippage .= "$1 ||";
    }
    else {
	$ippage .= "Saknas ||";
    }

    my @logevents = $bot->get_log_for_target("block", "now", "User:$_", "newer");

    $ippage .= $#logevents + 1 . " ||";

    my $blocks = "";
    foreach my $le (@logevents) {
	my $start = $le->{timestamp};
	my $stop = $le->{params}->{expiry};

	$start =~ s/(T|Z)/\ /g;
	$stop =~ s/(T|Z)/\ /g;

	$sth->execute($start, $stop);
	my $seconds = $sth->fetchrow_array();
	my $dur = Time::Seconds->new($seconds);
	my $durtext = $dur->pretty;
	$durtext =~ s/(\d+)\ years?/$1y/;
	$durtext =~ s/(\d+)\ months?/$1mo/;
	$durtext =~ s/(\d+)\ days?/$1d/;
	$durtext =~ s/(\d+)\ hours?/$1h/;

	$durtext =~ s/(\d+)\ minutes?/$1mi/;
	$durtext =~ s/\d+\ seconds?//;

	$durtext =~ s/[^0-9]0(h|mi)//g;
	$durtext =~ s/\,\ ?\,/\,/g;
	$durtext =~ s/\,\ ?$//g;

	$blocks .= $durtext . "; ";
    }

    $blocks =~ s/\;\ $//;

    $ippage .= "$blocks";
    
    my @descr;
    my $inetnum;
    foreach(split(/\n/, `whois $_`)) {
        if(/^([^\:]+)\:\ *(.*)/) {
	    if($1 eq "descr") {
		my $val = $2;
		push @descr, Encode::encode("utf-8", $val) unless($val =~ /(\#|\-|\*){5,}/);
	    }
	    if($1 eq "inetnum") {
		$inetnum = $2;
	    }
	}
    }
    my $whoisdesc = join(", ", @descr);

    $ippage .= "\n";

    push @{$networkpages->{$inetnum}}, { page => $ippage, whois => $whoisdesc };

}

my @nets = keys %{$networkpages};

my $pageh = qq!__NOTOC__\n\nDetta är en lista över användarsidor som har en av följande mallar: {{mall|Skolblockering}}, {{mall|Läsårsblockering}} eller {{mall|Lb}}. Listan uppdaterades senast: !;
$pageh .= getwikidate();
$pageh .= qq!. Totalt består listan av ! . ($#allips + 1) . qq! adresser fördelat på ! . ($#nets + 1) . qq! nät.!;
$pageh .= qq!\n\n!;

foreach my $net (sort bynetwork keys %{$networkpages}) {

    my $table = "";
    my $whois;
    $pageh .= "=== $net ===\n";


    foreach(@{$networkpages->{$net}}) {
	$whois = $_->{whois};
	$table .= $_->{page};
    }
    $pageh .= $whois . "\n";
    $pageh .= "{| class=\"wikitable\"\n! Adress !! Diskussion !! Bidrag !! IP-mall !! # Block !! Blockeringshistorik \n|-\n";
    $pageh .= $table;
    $pageh .= "|}\n\n";

}
#print $pageh;
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
