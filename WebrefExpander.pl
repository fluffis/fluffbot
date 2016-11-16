#!/usr/bin/perl

# Fluffbot expands links in <ref> with {{webbref}} and params from source
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
use lib "/data/project/perfectbot/Fluffbot/Mojolicious-5.02/lib";
use warnings;
use strict;

use Data::Dumper;
use Perlwikipedia;
use Text::Diff;

use LWP::Simple;

use Mojo::DOM;

use Getopt::Long;

# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");
#$bot->{debug} = 1;

open(P, "<../.pwd-Fluffbot") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Fluffbot", $pwd);

my $article = "Europaparlamentsvalet i Sverige 2014";

my $text = $bot->get_text($article);
my $newtext;


# domains to handle:
# dn.se
# gp.se
# sfi.se
# sverigesradio.se
# svt.se
# 

warn Dumper(parsesvtse(get("http://www.svt.se/kultur/kakan-1")));


sub parsetext {
    my $text = shift;

    

}



sub parsesvtse {
    my $text = shift;

    my %rets;

    my $m = Mojo::DOM->new($text);
    $m->find('meta')->each(sub {
	my $meta = shift;
	if($meta->attr('property') =~ /og\:title/) {
	    $rets{titel} = $meta->attr('content');
	}
	elsif($meta->attr('property') eq "og:site_name") {
	    $rets{utgivare} = $meta->attr('content');
	}
	elsif($meta->attr('property') eq "og:url") {
	    $rets{url} = $meta->attr('content');
	}
				       });

    $m->find('span')->each(sub {
	my $span = shift;
	if($span->attr('class') eq "svtArticleByline__author-name") {
	    push @{$rets{authors}}, $span->text;
	}
			   });

    $m->find('p')->each(
	sub {
	    my $p = shift;
	    if($p->attr('class') eq "svtTimestamp") {
		if($p->children->first->text =~ /Publicerad\:/) {
		    my $publd = $p->at('time')->text;
		    $publd =~ s/\ \-\ \d\d\:\d\d//;
		    $rets{'publdatum'} = $publd;
		}
	    }
	});

    return %rets;
}


sub parsedn {
    my $text = shift;
    my %rets;

    my $m = Mojo::DOM->new($text);
    $m->find('p')->each(sub {
	my $p = shift;
	if($p->attr('class') =~ /article-byline-txt/) {
	    if($p->content !~ /\<a/) {
		push @{$rets{authors}}, $p->children->first->text;
	    }
	}
			});
    $m->find('p')->each(
	sub {
	    my $p = shift;
	    if($p->attr('class') =~ /article\-published\-date/) {
		my $publd = $p->text;
		$publd =~ s/Publicerad\ //;
		$publd =~ s/\d\d\:\d\d//;
		$rets{'publdatum'} = $publd;
	    }
	});

    return %rets;

}

sub parsegpse {
    my $text = shift;

    my %rets;

    my $m = Mojo::DOM->new($text);
    $m->find('div')->each(
	sub {
	    my $div = shift;
	    if($div->attr('class') =~ /bylineContent/) {
		$div->children->each(
		    sub {
			my $child = shift;
			if($child->attr('class')  eq "name fn") {
			    $rets{author} = $child->text;
			}
		    });
	    }
	});


}


sub parseog {
    my $text = shift;

    my %rets;

    my $m = Mojo::DOM->new($text);
    $m->find('meta')->each(sub {
	my $meta = shift;
	if($meta->attr('property') =~ /og\:title/) {
	    $rets{titel} = $meta->attr('content');
	}
	elsif($meta->attr('property') eq "og:site_name") {
	    $rets{utgivare} = $meta->attr('content');
	}
	elsif($meta->attr('property') eq "og:url") {
	    $rets{url} = $meta->attr('content');
	}
				       });

    return %rets;
}

sub parsedcterms {
    my $text = shift;
    
    my %rets;

    my $m = Mojo::DOM->new($text);
    $m->find('meta')->each(
	sub {
	    my $meta = shift;
	    if($meta->attr('name') =~ /dc\.title/i ||
	       $meta->attr('name') =~ /dcterms\.title/i) {
		$rets{titel} = $meta->attr('content');
	    }
	    if($meta->attr('name') =~ /dc\.creator/i) {
		$rets{author} = $meta->attr('content');
	    }
	    if($meta->attr('name') =~ /dc\.date\.created/i ||
	       $meta->attr('name') =~ /dcterms\.created/i) {
		$rets{publdatum} = $meta->attr('content');
	    }
	    if($meta->attr('name') =~ /dc\.publisher/i ||
	       $meta->attr('name') =~ /dcterms\.publisher/i) {
		$rets{utgivare} = $meta->attr('content');
	    }

	});
}
