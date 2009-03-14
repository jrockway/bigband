package BigBand;
use Moose;
use Audio::XMMSClient;
use KiokuDB;

use BigBand::Sample;
use BigBand::Sampler;

use Time::HiRes qw(nanosleep);

use feature 'switch';
use constant STOP  => 2;
use constant PLAY  => 1;
use constant PAUSE => 0;

use namespace::clean -except => 'meta';
with 'MooseX::LogDispatch';

has 'kioku' => (
    is       => 'ro',
    isa      => 'KiokuDB',
    required => 1,
    default  => sub {
        KiokuDB->connect('hash'),
    },
);

has 'xmms' => (
    is         => 'ro',
    isa        => 'Audio::XMMSClient',
    lazy_build => 1,
    handles    => [qw/loop/], # enter event loop
);

sub _build_xmms {
    my $self = shift;
    my $xmms = Audio::XMMSClient->new('bigband');
    $xmms->connect;
    return $xmms;
}

has 'sampler' => (
    is         => 'ro',
    isa        => 'BigBand::Sampler',
    lazy_build => 1,
);

sub _build_sampler {
    my $self = shift;

    my $sampler = BigBand::Sampler->new(
        logger          => $self->logger,
        sample_callback => sub {
            $self->sample(@_);
        },
    );

    my $r = $self->xmms->playback_current_id;
    $r->wait;
    my $current_song_id = $r->value;
    $sampler->recv_song_change($current_song_id) if $current_song_id;

    return $sampler;
}

has [qw/pause_watcher current_song_id_watcher playtime_watcher/] => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_pause_watcher {
    my $self = shift;
    my $w = $self->xmms->broadcast_playback_status();
    $w->notifier_set(sub {
        my $event = shift;

        given($event){
            when(STOP){
                $self->sampler->recv_stop;
            }
            when(PAUSE){
                $self->sampler->recv_pause;
            }
            when(PLAY){
                $self->sampler->recv_play;
            }
        }

        return 1;
    });
    return $w;
}

sub _build_current_song_id_watcher {
    my $self = shift;
    my $w = $self->xmms->broadcast_playback_current_id;
    $w->notifier_set(sub {
        $self->sampler->recv_song_change(@_);
        return 1;
    });
    return $w;
}

sub _build_playtime_watcher {
    my $self = shift;
    my $w = $self->xmms->signal_playback_playtime;
    $w->notifier_set(sub {
         $self->sampler->recv_playback_tick($_[0]);
         return 1; # trigger restart
     });
    return $w;
}

sub BUILD {
    my $self = shift;

    $self->pause_watcher;
    $self->current_song_id_watcher;
    $self->playtime_watcher;
}

sub sample {
    my ($self, $sample) = @_;
    $self->logger->debug("Recording sample: ", join ' ', (map { $sample->$_ } qw/sample_taken song_id start duration/));

    if(!$sample->has_previous_sample){
        $self->logger->debug('Fresh lineage.');
    }

    my $s = $self->kioku->new_scope;
    $self->kioku->txn_do(sub {
        # ensure that only "beginning" samples become part of the root
        # set.
        # if($sample->has_previous_sample){
        #     $self->kioku->update($sample->previous_sample);
        # }
        # else {
            $self->kioku->insert($sample);
        # }
    });
}

1;
