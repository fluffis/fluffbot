#!/usr/bin/perl

# This is a skeleton. Remove this line and replace with basic purpose
# Copyright (C) User:Fluff 2016

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

use warnings;
use strict;

use Data::Dumper;
use MediaWiki::API;
use Text::Diff;
use DBI;
use Getopt::Long;

use utf8;
binmode STDOUT, ":utf8";

# Fluff@svwp.

my $dbh = DBI->connect("dbi:mysql:mysql_read_default_file=/data/project/perfectbot/.my.cnf;host=svwiki.labsdb;database=svwiki_p", undef, undef, {RaiseError => 1, AutoCommit => 1});

my $bot = MediaWiki::API->new();

# $botname can be either Fluffbot or Perfect
my $botname = "Fluffbot";

open(P, "</data/project/perfectbot/.pwd-$botname") || die("Could not find password");
my $pwd = <P>;
chomp($pwd);


$bot->{config}->{api_url} = "https://sv.wikipedia.org/w/api.php";
$bot->login({ lgname => $botname, lgpassword => $pwd}) || die("$bot->{error}->{code}: $bot->{error}->{details}");

