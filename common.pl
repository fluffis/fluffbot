#!/usr/bin/perl

use Encode;


my %char;
$char{'o'} = "\x{f6}"; # ö
$char{'a'} = "\x{e5}"; # å
$char{'aa'} = "\x{e4}"; # ä

sub getwikidate {

    my @months = qw/noll januari februari mars april maj juni juli augusti september oktober november december/;

    my $year = `/bin/date +"%Y"`;
    my $day = `/bin/date +"%d"`;
    my $monthnr = `/bin/date +"%m"`;

    chomp($year);
    chomp($monthnr);
    chomp($day);

    $monthnr =~ s/^0//;

    return "$day $months[$monthnr] $year";
}

sub getisodate {

    my $d = `/bin/date +"%FT%TZ"`;
    chomp($d);

    return $d;
}

sub utftoiso {
    my $text = shift;
    return Encode::encode("iso-8859-1", Encode::decode("utf-8", $text));
}


sub getpagenames {
    my $filename = shift;

    my @list;
    open(L, "<$filename") || die("Unable to open $filename: $!");
    while(my $l = <L>) {
	chomp($l);
	$l =~ /\*\ ?\[\[([^\:]*)\:([^\||\]]*)\|?([^\]]*)\]\]/g;
	
	push @list, {
	    ns => $1,
	    article => $2,
	    linktext => $3
	};
	
    }

    return @list;
}

1;
