package BigBand;
use Moose;
use Audio::XMMSClient;
use KiokuDB;

use BigBand::Sample;

has 'xmms' => (
    is       => 'ro',
    isa      => 'Audio::XMMSClient',
    required => 1,
    default  => sub {
        my $xmms = Audio::XMMSClient->new('bigband');
        $xmms->connect;
        return $xmms;
    },
    documentation => 'XMMS server to monitor',
);

has 'kioku' => (
    is       => 'ro',
    isa      => 'KiokuDB',
    required => 1,
);

has 'current_song_id' => (
    is            => 'rw',
    isa           => 'Int',
    predicate     => 'has_current_song_id',
    documentation => 'caches the ID of the currently-playing song; internal-use only',
);

has 'last_sample' => (
    is            => 'rw',
    isa           => 'BigBand::Sample',
    predicate     => 'has_last_sample',
    clearer       => 'clear_last_sample',
    documentation => 'caches the last simple, so we can maintain a linked list structure',
);

has [qw/pause_watcher current_song_id_watcher playtime_watcher/] => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_pause_watcher {
    my $self = shift;
    my $w = $self->xmms->broadcast_playback_status();
    $w->notifier_set(sub {
         my $event = shift;
         if($event == 0){
             warn "clear last sample";
             $self->clear_last_sample;
         }
     });
    return $w;
}

sub _build_current_song_id_watcher {
    my $self = shift;
    my $w = $self->xmms->broadcast_playback_current_id;
    $w->notifier_set(sub {
         warn "current song is @_";
         $self->current_song_id($_[0]),
     });
    return $w;
}

sub _build_playtime_watcher {
    my $self = shift;
    my $w = $self->xmms->signal_playback_playtime;
    $w->notifier_set(sub {
         $self->record_playback_tick($_[0]);
     });
    return $w;
}

sub BUILD {
    my $self = shift;

    my $r = $self->xmms->playback_current_id;
    $r->wait;
    $self->current_song_id($r->value);

    $self->pause_watcher;
    $self->current_song_id_watcher;
    $self->playtime_watcher;
}

sub record_playback_tick {
    my ($self, $song_time) = @_;

    my $s = $self->kioku->new_scope;

    my $sample = BigBand::Sample->new(
        song_id         => $self->current_song_id,
        song_time       => $song_time,

        $self->has_last_sample ? (
            previous_sample => $self->last_sample,
        ) : (),
    );

    if($self->has_last_sample){
        $self->last_sample->next_sample($sample);
    }

    $self->kioku->txn_do(sub {
        $self->kioku->insert($sample);
        $self->kioku->update($self->last_sample) if $self->has_last_sample;
    });

    $self->last_sample($sample);
}

1;
