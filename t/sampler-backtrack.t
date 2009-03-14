use strict;
use warnings;
use Test::More tests => 12;

use Log::Dispatch::Config::TestLog;
use BigBand::Sampler;
use Scalar::Util qw(refaddr);

my $sample_count = 0;
my $recent_sample;

my $sampler = BigBand::Sampler->new(
    sample_callback => sub {
        $sample_count++;
        $recent_sample = shift;
    },
);

isa_ok $sampler, 'BigBand::Sampler';
$sampler->recv_song_change(1);

is $sample_count, 0, 'no samples yet';

# play forward for 10 "seconds"
$sampler->recv_playback_tick($_) for 0..10;
is $sample_count, 0, 'still no samples';

# skip backwards 5 seconds
$sampler->recv_playback_tick(5);
is $sample_count, 1, 'the backtracking forces a sample to be sent';

my $original = $recent_sample;
is $original->duration, 10, 'first sample was for 10 seconds';
is $original->start, 0, 'started at 0';

$sampler->recv_playback_tick(6);
is $sample_count, 1, 'still only 1 sample';

$sampler->recv_quit;

is $sample_count, 2, 'got second sample';
my $second = $recent_sample;
is $second->duration, 1, 'next sample was one second';
is $second->start, 5, 'started at 5';

is refaddr $second->previous_sample, refaddr $original, 'prev link worked';
is refaddr $original->next_sample, refaddr $second, 'next link worked';

