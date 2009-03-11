#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use BigBand;
my $dsn = shift or die 'need dsn';
my $db = KiokuDB->connect($dsn, create => 1);

$SIG{TERM} = $SIG{INT} = sub {
    say "Stopping collection.";
    exit 0;
};

my $b = BigBand->new( kioku => $db );

say "Starting collection.";
$b->xmms->loop;

