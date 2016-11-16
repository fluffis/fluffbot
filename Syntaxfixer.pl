#!/usr/bin/perl

# Fluffbot corrects some syntaxerrors
# Copyright (C) User:Fluff 2015
# This module will search for different defined syntaxerrors and then repair the errors

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
#use Date::Manip;
use LWP::Simple;
use Text::Diff;
use charnames ':full';

binmode STDOUT, ":utf8";

#require "/home/dune/fluffbot/common.pl";



# which syntaxlist should we start from? will take a number.
my $startlist = defined $ARGV[0] ? sprintf("%03d", $ARGV[0]) : "048";
my $startpos = defined $ARGV[1] ? $ARGV[1] : 0;

#Fluff@svwp
my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");

$bot->{debug} = 1;
print qq!Starting up Fluffbot.\n\n!;

open(P, "</data/project/perfectbot/.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);


#my $list = get("http://toolserver.org/~sk/cgi-bin/checkwiki/checkwiki.cgi?project=svwiki&view=bots&id=$startlist&offset=$startpos&limit=100");
#(undef, $list) = split(/\<pre\>/, $list);
#($list, undef) = split(/\<\/pre\>/, $list);


my $list = get("https://tools.wmflabs.org/checkwiki/cgi-bin/checkwiki.cgi?project=svwiki&view=only&id=$startlist&limit=100&offset=$startpos");
if($list =~ /To\ do\:\ \<b\>0\<\/b\>/) {
    print "Nothing to do, zero articles to correct, exiting!";
    exit;
}

(undef, $list) = split(/<table\ /, $list);
($list, undef) = split(/\<\/table\>/, $list);
my @rows = split(/\<tr\>/, $list);

my %linklist;
my @articles;

foreach my $row (@rows) {
    my @ll;
    while($row =~ /https?\:\/\/([^\"]+)/) {
	push @ll, $1;
	$row =~ s/https?\:\/\/([^\"]+)//;
    }
    while($row =~ /\"checkwiki.cgi\?([^\"]+)/) {
	push @ll, "https://tools.wmflabs.org/checkwiki/cgi-bin/checkwiki.cgi?" . $1;
	$row =~ s/\"checkwiki.cgi\?([^\"]+)//;
    }
    $ll[0] =~ s/sv\.wikipedia\.org\/wiki\///;

    next if((defined $ll[3] && $ll[3] !~ /title\=/) || !defined($ll[0]));
    $linklist{$ll[0]} = (defined $ll[3] ? $ll[3] : $ll[2]);
    push @articles, $ll[0] unless(grep { $ll[0] eq $_ } @articles);
}

warn Dumper(%linklist);

if($articles[0] =~ /^DBI connect/) {
    print "Check Wikipedia failed to connect to db.";
    exit;
}

my @errorchecks = qw/021 048 050 057 064 075 077 088/;
my $i = 0;
my $unedited = 0;
foreach my $article (@articles) {
    next if(!$article);
    $i++;
    my $usearticlename;

    print "$i - Extracting text from $article\n";
    
    my $encarticle = Encode::encode("utf-8", $article);
    
    print " - fetching $article\n";
    my $origtext = $bot->get_text($article);
    if($origtext eq "2") {
	warn "Error fetching, trying with enc ($encarticle)";
	$origtext = $bot->get_text($article);
	$usearticlename = "encoded";
    }
    else {
	$usearticlename = "unencoded";
    }
    warn "Error fetching. Check article encoding." if($origtext eq "2");

    my $editedtext = $origtext;
    $editedtext = error021($article, $editedtext);
    $editedtext = error048($article, $editedtext);
    $editedtext = error050($article, $editedtext);
    $editedtext = error057($article, $editedtext);
    $editedtext = error064($article, $editedtext);
    $editedtext = error075($article, $editedtext);
    $editedtext = error077($article, $editedtext);
    $editedtext = error088($article, $editedtext);

    # Finishing up.
    if($editedtext eq $origtext) {
	print qq!=> $article is not changed\n!;
	$unedited++;
    }
    else {
	print qq!=> $article has changed. Will edit in 10 secs.\n!;
	print diff \$origtext, \$editedtext;
	sleep 10;
	$bot->edit(($usearticlename eq "encoded" ? $encarticle : $article), $editedtext, "Robot [[WP:Projekt wikifiering/Syntaxfel|fixar syntaxfel]] (list $startlist)");
	# Set as done.
	get($linklist{$article});
    }
}

print "\n================\n$unedited unedited articles found. You should be able to set offset to " . ($startpos + $unedited) . " next run.\n";

sub error021 {
    # Tar bort engelskansk category och ersätter med svenskansk kategori.
    my $article = shift;
    my $intext = shift;
    my $uttext = $intext;

    $uttext =~ s/\[\[Category\:/\[\[Kategori\:/g;

    return $uttext;

}

sub error048 {
    # Replaces links to the own article with bold text.
    my $article = shift;
    my $intext = shift;
    my $uttext = $intext;
    
    return $uttext if($uttext =~ /\#(OMDIRIGERING|REDIRECT)/i);

    $uttext =~ s/\[\[$article\]\]/\'\'\'$article\'\'\'/g;
    $uttext =~ s/\[\[$article\|([^\]]+)\]\]/\'\'\'$1\'\'\'/g;

    $article = utftest($article);
    $uttext =~ s/\[\[$article\]\]/\'\'\'$article\'\'\'/g;
    $uttext =~ s/\[\[$article\|([^\]]+)\]\]/\'\'\'$1\'\'\'/g;

    $uttext =~ s/\'{6}/\'\'\'/g;

    return $uttext;
}

sub error050 {
    # edits ndash to unicode char
    my $article = shift;
    my $intext = shift;

    $intext =~ s/\&ndash\;/\N{EN DASH}/g;
    $intext =~ s/\&\#(x2013|8211)\;/\N{EN DASH}/g;

    return $intext;
}

sub error057 {
    # Removes : at the end of a headline, ie: == Rubrik: ==

    my $article = shift;
    my $intext = shift;
    my $uttext = $intext;

    $uttext =~ s/^(\=+)([^:|^\n]+)\:\ ?(\=+)/$1$2$3/gm;

    return $uttext;
}


sub error064 {
    # Letar efter lÃ¤nkar dÃ¤r man har [[a|a]] istÃ¤llet fÃ¶r [[a]]
    my $article = shift;
    my $intext = shift;
    my $uttext = $intext;

    my @matches = $intext =~ /\[\[([^\]]+)\]\]/g;
    foreach(@matches) {
	next if(!/\|/);
	@_ = split(/\|/, $_);
	chomp($_[0]);
	chomp($_[1]);
	next if(!defined $_[1]);    
	
	$uttext =~ s/\[\[$_[0]\|$_[0]\]\]/\[\[$_[0]\]\]/g if($_[0] eq $_[1]);
    }
    
    # Matchar tex bilder med bildtexter
    # Tex: [[Bild:test.jpg|600px|En bild pÃ¥ ett [[test]] som Ã¤r fint]]
    foreach($intext =~/(\[\[([^\[\]]+)\[\[([^\]]+)\]\]([^\]]+)\]\])/g) {
$_ =~ /\[\[([^\[\]]+)\[\[([^\]]+)\]\]([^\]]+)\]\]/;
my $match = $2;
@_ = split(/\|/, $match);
$uttext =~ s/\[\[$_[0]\|$_[1]\]\]/\[\[$_[0]\]\]/ if(defined $_[1] && $_[0] eq $_[1]);
    }
    
#    my $diff = diff \$uttext, \$intext;
#    print utftest($diff);
    return $uttext;
}


sub error075 {
    # ErsÃ¤tter ::* med *** som ger samma intendering.
    my $article = shift;
    my $intext = shift;
    my $uttext = $intext;

    while($uttext =~ /^(\:+)\*/m) {
	my $cmatch = length($1);
	my $replace = "*" x ($cmatch + 1);
	$uttext =~ s/^(\:{$cmatch})\*/$replace/mg;
    }
    return $uttext;

}

sub error077 {
    my $article = shift;
    my $intext = shift;
    my @outtext;

    foreach my $line (split(/\n/, $intext)) {
	if($line =~ /^\[\[(Bild|Fil|Image|File)\:/ && $line =~ /\<small\>/ && $line =~ /\<\/small\>/) {
	    my $lmatch = () = $line =~ /\[\[/;
	    my $rmatch = () = $line =~ /\]\]/;
	    if($lmatch == $rmatch) {

		my @lineparts = split(/\<\/\ *small\>/, $line);
		if($lineparts[-1] =~ /\]\]/) {
		    $line =~ s/\<\/?\ *small\>//g;
		}
	    }
	}
	push @outtext, $line;
    }

    return join("\n", @outtext);
}

sub error088 {
    my $article = shift;
    my $intext = shift;

    # standardsortering eller defaultsort med mellanslag som fÃ¶rsta bokstav.
    $intext =~ s/\{\{(DEFAULTSORT|STANDARDSORTERING)\:(\ )+([^\}]+)\}/\{\{$1\:$3\}/i;

    return $intext;
}



sub utftest {
    my $str = shift;
    
    unless(grep { ord($_) == 194 || ord($_) == 195 || ord($_) == 196 } split(//, $str)) {
#warn "Detected non-utf8-string";
	$str = encode_utf8($str);
    }
    return $str;
}

