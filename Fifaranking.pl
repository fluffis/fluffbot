#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use JSON::PP;

my $jsondata = get("http://www.fifa.com/common/fifa-world-ranking/_ranking_matchpoints_totals.js");

my $rank = JSON::PP->new->utf8->decode($jsondata);

my $i = 0;
foreach my $c (@{$rank}) {
    $i++;
    print $c->{countrycode} . " has " . $c->{points} . " at pos $i\n";
}
