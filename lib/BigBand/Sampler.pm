package BigBand::Sampler;
use Moose;
use BigBand::Sample;
use Time::HiRes;

use namespace::clean -except => 'meta';

with 'MooseX::LogDispatch';

# this module receives events from XMMS, and emits ::Sample objects
# when appropriate

has 'sample_callback' => (
    is            => 'ro',
    isa           => 'CodeRef',
    required      => 1,
    documentation => 'Called with a BigBand::Sample object when one is ready.',
);

# these are used to produce samples, they can change at any time, and
# don't mean much outside of this class (so don't use them there)

has 'current_song_id' => (
    is            => 'rw',
    isa           => 'Int',
    predicate     => 'has_current_song_id',
    documentation => 'caches the ID of the currently-playing song',
);

has 'last_sample' => (
    is            => 'rw',
    isa           => 'BigBand::Sample',
    predicate     => 'has_last_sample',
    clearer       => 'clear_last_sample',
    documentation => 'set automatically when a sample is sent; we keep this around so that we can build the linked-list structure between samples (see C<_make_sample>, which uses this sample to build the C<current_sample>)',
);

sub _make_sample {
    my ($self, @args) = @_;

    return BigBand::Sample->new(
        @args, (
            $self->has_last_sample ?
              (previous_sample => $self->last_sample) :
              (),
        ),
    );
}

has 'current_sample' => (
    is            => 'rw',
    isa           => 'BigBand::Sample',
    predicate     => 'has_current_sample',
    clearer       => 'clear_current_sample',
    documentation => 'we accumulate data into this sample for as long as possible; then it is sent to the caller and the attribute is reset',
);

has 'last_tick' => (
    is            => 'rw',
    isa           => 'Int',
    predicate     => 'has_last_tick',
    clearer       => 'clear_last_tick',
    documentation => 'last time when the C<current_sample> was updated',
);

# use the logger singleton during testing
has '+use_logger_singleton' => ( default => 1 );

sub send_current_sample {
    my ($self) = @_;
    confess 'logic error: calling send_current_sample without a current sample'
      unless $self->has_current_sample;

    $self->sample_callback->($self->current_sample);
    $self->last_sample($self->current_sample);
    $self->clear_current_sample;
    $self->clear_last_tick;
}

sub DEMOLISH {
    my $self = shift;
    warn "DEMOLISHING $self with an unsent current_sample"
      if $self->has_current_sample;
}

## event handlers

sub recv_quit {
    my $self = shift;
    $self->logger->debug("quit");
    $self->send_current_sample if $self->has_current_sample;
}

sub recv_pause {
    my $self = shift;
    $self->logger->debug("pause");
    $self->send_current_sample;
    $self->clear_last_sample;
}

sub recv_stop {
    my $self = shift;
    $self->logger->debug("stop");
    $self->send_current_sample;
    $self->clear_last_sample;
}

sub recv_play {
    my $self = shift;
    $self->logger->debug("play (nop)");
    # create new sample?
}

sub recv_song_change {
    my ($self, $song_id) = @_;
    $self->logger->debug("song change to $song_id");
    $self->send_current_sample if $self->has_current_sample;
    $self->clear_last_tick;
    $self->current_song_id($song_id);
    # simulate a tick, since we usually don't get one for a few milliseconds
    # $self->recv_playback_tick(0);
}

sub _start_new_sample {
    my $self = shift;
    my $song_time = shift;
    $self->logger->debug('creating initial sample');
    $self->current_sample(
        $self->_make_sample(
            song_id  => $self->current_song_id,
            start    => $song_time,
            duration => 0,
        ),
    );
    $self->last_tick( $song_time );
}

sub recv_playback_tick {
    my ($self, $song_time) = @_;

    confess 'Internal error: got a playback tick, but no song is currently playing'
      unless $self->has_current_song_id;

    if(!$self->has_current_sample){
        $self->_start_new_sample($song_time);
    }

    elsif($self->has_last_tick &&
            $self->has_current_song_id &&
              $self->has_current_sample){
        # in the "middle" of recording a song
        my $last_tick = $self->last_tick;
        my $since_last_tick = $song_time - $self->last_tick;

        my $song_elapsed = $self->current_sample->duration + $since_last_tick;
        my $wall_elapsed = 1000 * (
            Time::HiRes::time() - $self->current_sample->sample_taken,
        );

        my $wall_song_jitter = $song_elapsed - $wall_elapsed;
        if( $wall_song_jitter > 1000 && $since_last_tick >= 0 ){
            # we skipped forwards
            # (the 1000 is just a heuristic, usually this is under 70)
            $self->logger->debug('skipping forwards');
            $self->send_current_sample;
            $self->_start_new_sample($song_time);
        }
        elsif( $since_last_tick >= 0 ){
            # $self->logger->debug('tick forwards '. ($song_time - $last_tick));
            $self->current_sample->add_to_duration( $since_last_tick );
            $self->last_tick( $song_time );
        }
        else {
            # we skipped backwards
            $self->logger->debug('skipping backwards');
            $self->send_current_sample;
            $self->_start_new_sample($song_time);
        }
    }
    else {
        $self->logger->error('unexpected case: '. $self->dump);
    }

}

1;
