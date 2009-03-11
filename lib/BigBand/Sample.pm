package BigBand::Sample;
use KiokuDB::Class;

use Time::HiRes;

use namespace::clean -except => 'meta';

has 'sample_time' => (
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

has 'song_time' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'previous_sample' => (
    traits    => ['KiokuDB::Lazy'],
    is        => 'ro',
    isa       => 'BigBand::Sample',
    predicate => 'has_previous_sample',
);

has 'next_sample' => (
    traits    => ['KiokuDB::Lazy'],
    is        => 'rw',
    isa       => 'BigBand::Sample',
    predicate => 'has_next_sample',
    weak_ref  => 1,
);

1;
