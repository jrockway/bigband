package BigBand::Sample;
use KiokuDB::Class;

use Time::HiRes;

use namespace::clean -except => 'meta';

has 'sample_taken' => (
    is       => 'ro',
    isa      => 'Num',
    default  => sub { Time::HiRes::time() },
    required => 1,
);

has 'song_id' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'start' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

# unit = miliseconds
has 'duration' => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has '_duration_update_history' => (
    is       => 'ro',
    isa      => 'ArrayRef',
    default  => sub { +[] },
    required => 1,
);

sub add_to_duration {
    my ($self, $time) = @_;
    $self->duration( $self->duration + $time );
    push @{$self->_duration_update_history}, [ Time::HiRes::time(), $time ];
}

has 'previous_sample' => (
    traits    => ['KiokuDB::Lazy'],
    is        => 'ro',
    isa       => 'BigBand::Sample',
    predicate => 'has_previous_sample',
    trigger   => sub {
        my ($self, $prev, $attr) = @_;
        $prev->next_sample($self); # maintain the double-linking
    }
);

has 'next_sample' => (
    traits    => ['KiokuDB::Lazy'],
    is        => 'rw',
    isa       => 'BigBand::Sample',
    predicate => 'has_next_sample',
    weak_ref  => 1,
);

1;
