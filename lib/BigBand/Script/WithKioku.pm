package BigBand::Script::WithKioku;
use Moose::Role;
use MooseX::Types::Path::Class;

use KiokuDB;
use KiokuDB::Backend::BDB;

has 'storage' => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    required      => 1,
    coerce        => 1,
    documentation => 'directory where the database will live (created if necessary)',
);

has 'kioku' => (
    traits     => ['NoGetopt'],
    is         => 'ro',
    lazy_build => 1,
);

sub _build_kioku {
    my $self = shift;
    my $dir = $self->storage;
    my $db = KiokuDB->connect("bdb:dir=$dir", create => 1);
    return $db;
}

1;
