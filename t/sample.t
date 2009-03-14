use strict;
use warnings;
use Test::More tests => 11;
use Scalar::Util qw(refaddr);

use ok 'BigBand::Sample';

my $s = BigBand::Sample->new(
    sample_taken => 0,
    song_id      => 0,
    start        => 0,
    duration     => 60,
);

isa_ok $s, 'BigBand::Sample';
ok !$s->has_previous_sample;
ok !$s->has_next_sample;

my $t = BigBand::Sample->new(
    sample_taken    => 60,
    song_id         => 1,
    start           => 0,
    duration        => 60,
    previous_sample => $s,
);

isa_ok $t, 'BigBand::Sample';
ok !$s->has_previous_sample;

ok $s->has_next_sample;
is refaddr $t, refaddr $s->next_sample;

ok $t->has_previous_sample;
is refaddr $s, refaddr $t->previous_sample;

ok !$t->has_next_sample;

