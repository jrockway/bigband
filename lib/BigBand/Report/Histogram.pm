package BigBand::Report::Histogram;
use Moose;
use MooseX::AttributeHelpers;
use DateTime;

has 'song_data' => (
    metaclass => 'Collection::Hash',
    is        => 'ro',
    isa       => 'HashRef',
    required  => 1,
    default   => sub { {} },
    provides  => {
        keys => 'available_songs',
    },
);

sub add_sample {
    my ($self, $sample) = @_;

    my $song = $sample->song_id;
    my $time = $sample->start;
    my $dur = $sample->duration;

    $self->song_data->{$song} ||= [];
    my $song_data = $self->song_data;

    my $i;
    for( $i = 0; $i < $dur; $i+=10){
        $song_data->{$song}[int(($time + $i)/1000)]+=10;
    }
    return;
}

sub histogram_for {
    my ($self, $song) = @_;
    return [ map { ( $_ || 0 ) / 1000 } @{$self->song_data->{$song}} ];
}

1;
