#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use BigBand;
my $dsn = shift or die 'need dsn';
my $db = KiokuDB->connect($dsn);


my %songs;

my $scope = $db->new_scope;
my $all = $db->backend->all_entries;

say "Calculating...";
while( my $chunk = $all->next ){
    for my $item (@$chunk){
        my $sample = $db->lookup($item->id);
        $songs{$sample->song_id}{int $sample->song_time/1000}+=0.1; # length of sample
    }
}

use DDS;
say Dump(\%songs);
