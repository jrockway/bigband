#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';

use FindBin qw($Bin);
use lib "$Bin/../lib";

use BigBand::Script::SessionSummary;
BigBand::Script::SessionSummary->new_with_options->run;
