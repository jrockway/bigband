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

    for( my $i = 0; $i < $sample->duration; $i++){
        $self->song_data->{$song}[int(($time + $i)/3000)]++;
    }

    return;
}

sub histogram_for {
    my ($self, $song) = @_;
    return [ map { $_ / 3000 } @{$self->song_data->{$song}} ];
}

1;
