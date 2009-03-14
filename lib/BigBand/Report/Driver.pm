package BigBand::Report::Driver;
use Moose;
use MooseX::AttributeHelpers;

has 'report_classes' => (
    metaclass => 'Collection::Hash',
    is        => 'ro',
    isa       => 'HashRef',
    required  => 1,
    provides  => {
        keys => 'list_report_types',
    },
);

has 'report_instances' => (
    metaclass  => 'Collection::Hash',
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    provides   => {
        get    => 'get_report',
        values => 'get_reports',
    },
);

sub _build_report_instances {
    my $self = shift;

    my %h;
    for my $type ($self->list_report_types){
        $h{$type} = $self->report_classes->{$type}->new;
    }
    return \%h;
}

sub _for_each_report {
    my $self = shift;
    my ($method, @args) = @_;
    for my $type ($self->list_report_types){
        my $instance = $self->get_report($type);
        $instance->$method(@args);
    }
}

before add_sample => sub {
    my ($self, $sample) = @_;
    confess "$sample is not a sample" unless $sample->isa('BigBand::Sample');
};

sub add_sample {
    my ($self, $sample) = @_;
    $self->_for_each_report('add_sample', $sample);
}

sub add_chain {
    my ($self, $sample) = @_;
    do {
        $self->add_sample($sample);
    } while ($sample = $sample->next_sample);
}

1;
