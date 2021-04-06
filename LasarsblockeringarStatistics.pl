#!/usr/bin/perl

# Calculating users with certain templates and not blocked
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

$| = 1;


use strict;
use MediaWiki::API;
use Encode;
use Data::Dumper;
use Getopt::Std;
use Text::Diff;
use DBI;
#use Date::Manip;
use DateTime;


my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;hostname=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $api = MediaWiki::API->new();
$api->{config}->{api_url} = 'https://sv.wikipedia.org/w/api.php';


open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$api->login({
    lgname => 'Fluffbot',
    lgpassword => $pwd
	    }) || die("Could not login: " . $api->{error}->{code});


# Get page history of Fluffbot
# parse each page for IP-addresses
# Check if users are blocked (in bulk?)
# 

my $response = $api->api({
    action => 'query',
    prop => 'revisions',
    titles => Encode::decode("utf-8", "User:Fluffbot/Lista över läsårsblockerade"),
    rvstart => '2016-07-01T00:00:00Z',
    rvdir => 'newer',
    rvlimit => 5000,
    rvprop => 'ids|timestamp|content'
		       }, {max => 10}) || die("Error: " . $api->{error}->{details});

my @blocks;

my @edits = @{$response->{'query'}->{'pages'}->{'7988796'}->{'revisions'}};
my $lastedit;

foreach my $edit (@edits) {
    $lastedit = $edit->{timestamp};
    foreach my $row (split(/\n/, $edit->{'*'})) {
#	print "Parsing row: $row - ";
	if($row =~ /^\|\ \[\[User\:([^\|]+)/) {
	    push @blocks, $1 unless(grep { $1 == $_ } @blocks);
#	    print "found $1\n";
	}
	elsif($row =~ /^\#\ \[\[User\:([^\|]+)/) {
	    push @blocks, $1 unless(grep { $1 == $_ } @blocks);
#	    print "found $1\n";
	}
	elsif($row =~ /^\=\=\=\=\ \[\[User\:([^\|]+)/) {
	    push @blocks, $1 unless(grep { $1 == $_ } @blocks);
#	    print "found $1\n";
	}
#	print "nothing found\n";
    }

}

print "== Total IP-address count ==\n";
print "Scanning " . scalar @edits . " revisions of the talk page resulted in " . scalar @blocks . " IP-addresses. ";
print "The last revision has timestamp $lastedit.\n\n";

my %still_blocked;
my @not_blocked;

my $sth = $dbh->prepare(qq!SELECT * FROM ipblocks WHERE ipb_address = ?!);
foreach my $block (@blocks) {
    $sth->execute($block);
    if($sth->rows()) {
	my $ref = $sth->fetchrow_hashref();
	$still_blocked{$block} = $ref->{ipb_expiry};
    }
    else {
	push @not_blocked, $block unless(grep { $block == $_ } @not_blocked);
    }

}


print "=== Blocked (" . (scalar (keys %still_blocked) + 1) .")===\n";
foreach my $blocked (sort byusername keys %still_blocked) {
    print "* $blocked ($still_blocked{$blocked})\n";
}

print "\n\n";
print "=== Not blocked (" . (scalar @not_blocked + 1) . ")===\n";
foreach my $notblocked (sort byusername @not_blocked) {
    print "* $notblocked\n";

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
