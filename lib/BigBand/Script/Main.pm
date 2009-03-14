package BigBand::Script::Main;
use Moose;
use MooseX::Types::Path::Class;

use BigBand;
use Log::Dispatch;
use Log::Dispatch::Screen;
use KiokuDB;

with 'MooseX::Getopt';

has 'storage' => (
    is            => 'ro',
    isa           => 'Path::Class::Dir',
    required      => 1,
    coerce        => 1,
    documentation => 'directory where the database will live (created if necessary)',
);

has 'log_level' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => sub { 'debug' },
    documentation => 'level of messages to log; defaults to "debug"',
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

has 'logger' => (
    traits     => ['NoGetopt'],
    is         => 'ro',
    lazy_build => 1,
);

sub _build_logger {
    my $self = shift;
    my $logger = Log::Dispatch->new( callbacks => sub {
        my %args = @_;
        return "[". $args{level}. "] ". $args{message}. "\n";
    });

    $logger->add( Log::Dispatch::Screen->new(
        name      => 'screen',
        min_level => 'debug',
    ));

    return $logger;
}

sub run {
    my $self = shift;
    my $b = BigBand->new(
        logger => $self->logger,
        kioku  => $self->kioku,
    );

    $SIG{TERM} = $SIG{INT} = sub {
        $self->logger->info("Stopping collection.");
        $b->sampler->recv_quit;
        $self->clear_kioku;
        exit 0;
    };

    $self->logger->info("Starting collection.");
    $b->loop;
}

1;
