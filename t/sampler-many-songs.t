use strict;
use warnings;
use Test::More tests => 11;

use Log::Dispatch::Config::TestLog;
use BigBand::Sampler;

my @samples;

my $sampler = BigBand::Sampler->new(
    sample_callback => sub {
        push @samples, $_[0];
    },
);


isa_ok $sampler, 'BigBand::Sampler';

$sampler->recv_song_change(1);
$sampler->recv_playback_tick($_) for 0..10;
$sampler->recv_song_change(2);
$sampler->recv_playback_tick($_) for 0..10;
$sampler->recv_song_change(3);
$sampler->recv_playback_tick($_) for 0..10;
$sampler->recv_stop;

is scalar @samples, 3, 'got 3 samples';

is $samples[0]->song_id, 1, 'first song is 1';
is $samples[0]->duration, 10, 'song is 10 seconds long';

is $samples[1]->song_id, 2;
is $samples[1]->duration, 10, 'song is 10 seconds long';

is $samples[2]->song_id, 3;
is $samples[2]->duration, 10, 'song is 10 seconds long';

my $i = 1;
my $sample = $samples[0];
do {
    is $sample->song_id, $i, 'testing linked list structure';
} while($i++ && ($sample = $sample->next_sample));
