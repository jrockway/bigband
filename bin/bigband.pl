#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use BigBand;
use Log::Dispatch;
use Log::Dispatch::Screen;
use KiokuDB;

my $dsn = shift or die 'need dsn';
my $db = KiokuDB->connect($dsn, create => 1);

my $logger = Log::Dispatch->new( callbacks => sub {
    my %args = @_;
    return "[". $args{level}. "] ". $args{message}. "\n";
});

$logger->add( Log::Dispatch::Screen->new(name => 'screen', min_level => 'debug') );

my $b = BigBand->new( kioku => $db, logger => $logger );

$SIG{TERM} = $SIG{INT} = sub {
    $logger->info("Stopping collection.");
    $b->sampler->recv_quit;
    exit 0;
};

$logger->info("Starting collection.");
$b->xmms->loop;

