#!/usr/bin/perl

use warnings;
use strict;

use DBI;
use XML::LibXML::Reader;
use MediaWiki::API;
use Data::Dumper;
use utf8;
use Encode;


my $api = MediaWiki::API->new();
$api->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);


$api->login({
    lgname => 'Fluffbot',
    lgpassword => $pwd
	    });


my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.analytics.db.svc.wikimedia.cloud;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $r = XML::LibXML::Reader->new({FD => fileno(STDIN), schema => 'http://www.mediawiki.org/xml/export-0.10/'});

my $title;
my $ns;
my $id;
my $revision;
my $text;

my %still_blocked;
my @not_blocked;
my %tmpl;

while($r->read()) {
    if($r->name() eq "page") {
	if($r->nextElement('title')) {
	    $title = $r->readInnerXml();
	}

	if($r->nextElement('ns')) {
	    $ns = $r->readInnerXml();
	}
	if($r->nextElement('id')) {
	    $id = $r->readInnerXml();
	}
	if($r->nextElement('revision')) {
	    $text = processRevision($r);
	}
	
	if($ns == 3 && $title =~ /Anv\x{e4}ndardiskussion\:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
	        # 3 = User talk
	    if($text =~ /\{\{(mall\|)?(lb|l\x{e4}s\x{e5}rsblockering|skolblockering)/i) {
		
		print "Found $title with template $1$2\n";
		$tmpl{$1 . $2}++;
		my (undef, $ip) = split(/\:/, $title);
		my ($res, $expiry) = checkBlockedMySQL($ip);
		if($res ne "-1") {
		    $still_blocked{$ip} = $expiry;
		}
		else {
		    push @not_blocked, $ip;
		}
	    }
	}
    }
}

warn Dumper(%tmpl);

$r->close();

print "== Rapport om lb-mallar ==\n";
print "Hittade " . (scalar (keys %still_blocked) + 1) . " IP-adresser med lb-mallar som fortfarande är blockerade. Utöver det finns " . scalar @not_blocked . " användare som har lb-mall men som inte är blockerade.\n\n";
print "=== Blockerade ===\n";
foreach my $blocked (sort byusername keys %still_blocked) {
    print "* $blocked ($still_blocked{$blocked})\n";
}

print "\n\n=== Ej blockerade ===\n";
foreach my $notblocked (sort byusername @not_blocked) {
    print "* $notblocked\n";
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

    return $text;
}


sub checkBlocked {

    my $ip = shift;

    my $res = $api->api({
	action => 'query',
	list => 'blocks',
	bkprop => 'id|expiry|reason',
	bkip => $ip
			});
        
    if(defined $res->{query}->{blocks}) {
	my $block = shift @{$res->{query}->{blocks}};
	
	return $block->{expiry};
    }
    else {
	return -1;
    }

}

sub checkBlockedMySQL {

    my $ip = shift;

    my $sth = $dbh->prepare(qq!SELECT * FROM ipblocks WHERE ipb_address = ?!);
    $sth->execute($ip);
    if($sth->rows()) {
	my $ref = $sth->fetchrow_hashref();
	
	return 1, $ref->{ipb_expiry};
    }
    else {
	return -1, undef;
    }
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
