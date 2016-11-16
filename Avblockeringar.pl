#!/usr/bin/perl

# Fluffbot listing requests for unblock at given page.
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
use warnings;
use strict;
use Perlwikipedia;
use Encode;
use Data::Dumper;



# Fluff@svwp.

my $bot = Perlwikipedia->new("fluffbot");

$bot->set_wiki("sv.wikipedia.org", "w");
$bot->{debug} = 1;

open(P, "</data/project/perfectbot/.pwd-Perfect") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);

$bot->login("Perfect", $pwd);

my $oldtext = $bot->get_text("Wikipedia:Blockeringar/Beg\x{e4}ran om avblockering");
my @oldpages;
while($oldtext =~ /\*\ \[\[([^\]]+)\]\]/) {
    $oldtext =~ s/\*\ \[\[([^\]]+)\]\]//;
    push @oldpages, $1;
}

my $i = 0;
my $text = "{{Wikipedia:Beg\x{e4}ran_om_avblockering/textmall}}\n\n";

my @pages;
if(@pages = sort $bot->get_all_pages_in_category("Kategori:Beg\x{e4}ran om avblockering")) {
    foreach(@pages) {
#       my $newid;
#       my $oldid;
#       foreach my $ref ($bot->get_history($_, 20)) {
#           # Fetching history to find where unblock was inserted
#           my $atext = $bot->get_text($_, $ref->{revid});
#           if($atext =~ /\{\{avblockering\|/i) {
#               $newid = $ref->{'revid'};
#           }
#           else {
#               $oldid = $ref->{'revid'};
#               last;
#           }
#       }

        $i++;
        $text .= "* [[$_]]\n";
#       if($newid && $oldid) {
#           $_ =~ s/\ /\_/g;
#           $text .= "([https://sv.wikipedia.org/w/index.php?title=$_&diff=$newid&oldid=$oldid diff])\n";
#       }
#       else {
#           $text .= "\n";
#       }
    }
}

my @addedpages;
my @removedpages;
foreach my $page (@oldpages) {
    next if(!$page);
    unless(grep { $page eq $_ } @pages) {
        push @removedpages, $page;
    }
}

foreach my $page (@pages) {
    next if(!$page);
    unless(grep { $page eq $_ } @oldpages) {
        push @addedpages, $page;
    }
}
my $editcom = "Robot upppdaterar: ";
if($i == 0) {
    $editcom .= "Ingen beg\x{e4}ran";
}
elsif($i == 1) {
    $editcom .= "1 beg\x{e4}ran";
}
else {
    $editcom .= "$i beg\x{e4}randen";
}

if(defined $addedpages[0]) {
    $editcom .= " L\x{e4}gger till: ";
    $editcom .= " [[:" . join("]], [[:", @addedpages) . "]]";
}
if(defined $removedpages[0]) {
    $editcom .= " Tar bort: ";
    $editcom .= " [[:" . join("]], [[:", @removedpages) . "]]";
}

$bot->edit("Wikipedia:Blockeringar/Beg\x{e4}ran om avblockering", $text, $editcom);
