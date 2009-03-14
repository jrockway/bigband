package BigBand::Script::SongSummaryWeb;
use 5.010;
use BigBand::Report::Driver;
use BigBand::Report::Histogram;
use BigBand;
use Data::Section '-setup';
use HTTP::Engine;
use Moose;
use Path::Router;
use Template::Refine::Fragment;
use Template::Refine::Processor::Rule::Select::CSS;
use Template::Refine::Processor::Rule::Transform::Replace;
use Template::Refine::Processor::Rule;
use Chart::Clicker;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Data::DataSet;
use Template::Refine::Utils qw(simple_replace replace_text);


with 'BigBand::Script::WithKioku';

has 'engine' => (
    is         => 'ro',
    isa        => 'HTTP::Engine',
    lazy_build => 1,
);

sub _build_engine {
    my $self = shift;
    my $e = HTTP::Engine->new(
        interface => {
            module => 'POE',
            args   => {
                host => 'localhost',
                port =>  1978,
            },
            request_handler => sub {
                $self->handle_request(@_);
            },
        },
    );
    return $e;
}

has 'router' => (
    is         => 'ro',
    isa        => 'Path::Router',
    lazy_build => 1,
);

sub _build_router {
    my $self = shift;

    my $router = Path::Router->new;
    $router->add_route( '/' =>
        defaults => {
            action => 'index',
        },
        target => sub { $self->index_page(@_) },
    );

    $router->add_route( '/image/by-song/:song_id/song_histogram.png' =>
        defaults => {
            action => 'image',
            image  => 'song_histogram',
        },
        target => sub { $self->song_image(@_) },
    );

    return $router;
}

has 'reports' => (
    is         => 'ro',
    isa        => 'BigBand::Report::Driver',
    lazy_build => 1,
    handles    => ['get_report'],
);

sub _build_reports {
    my $self = shift;

    say "Building reports...";
    my $reports = BigBand::Report::Driver->new(
        report_classes => {
            histogram => 'BigBand::Report::Histogram',
        },
    );

    my $s = $self->kioku->new_scope;
    say "Getting entries...";
    my $all = $self->kioku->backend->all_entries;
    say "Aggregating entries...";

    while( my $chunk = $all->next ){
        for my $entry (@$chunk){
            my $obj = $self->kioku->lookup($entry->id);
            $reports->add_sample($obj);
        }
    }
    say "done";
    return $reports;
}


sub run {
    my $self = shift;
    my $e = $self->engine;
    say "Server started at http://", $e->interface->host, ":", $e->interface->port;
    $e->run;
    POE::Kernel->run;
}

sub handle_request {
    my ($self, $req) = @_;
    my $action = $self->router->match( $req->uri->path );

    return $self->not_found_page unless $action;

    return $action->target->($req, $action);
}

sub response {
    my ($self, @args) = @_;
    return HTTP::Engine::Response->new(
        @args,
    );
}

sub not_found_page {
    my $self = shift;
    my $req = shift;

    warn "not found: ". $req->uri->path;

    $self->response(
        status => 404,
        body   => 'not found',
    );
}

sub index_page {
    my ($self, $req) = @_;

    my @songs = $self->get_report('histogram')->available_songs;
    my @histograms =
      grep { scalar @{$_->[1]} > 10 } # 30 seconds of data
      map { [ $_, $self->get_report('histogram')->histogram_for($_) ] } @songs;

    my @images = map { $self->_one_histogram_image($req, $_->[0]) } @histograms;


    my $f = Template::Refine::Fragment->new_from_string(
        ${$self->section_data('index')},
    );

    $f = $f->process(
        Template::Refine::Processor::Rule->new(
            selector => Template::Refine::Processor::Rule::Select::CSS->new(
                pattern => 'div',
            ),
            transformer => Template::Refine::Processor::Rule::Transform::Replace->new(
                replacement => sub {
                    my $node = shift;
                    $node->appendChild($_) for @images;
                    return $node;
                },
            ),
        ),
    );

    return $self->response(
        body => '<html><head><title>Index</title></head><body>'.$f->render.'</body></html>',
    );
}

sub song_image {
    my ($self, $req, $match) = @_;
    my $song_id = $match->mapping->{song_id};

    my $histogram = $self->get_report('histogram')->histogram_for($song_id);

    my $cc = Chart::Clicker->new;
    my $i = 0;
    my $series = Chart::Clicker::Data::Series->new(
        keys    => [map { $i++ } @$histogram],
        values  => [map { $_ || 0 } @$histogram],
    );

    my $ds = Chart::Clicker::Data::DataSet->new(series => [ $series ]);
    $cc->add_to_datasets($ds);
    $cc->draw;

    return $self->response(
        content_type => 'image/png',
        body => scalar $cc->data,
    );
}

sub _one_histogram_image {
    my ($self, $req, $song_id) = @_;
    my $f = Template::Refine::Fragment->new_from_string(
        ${$self->section_data('one_histogram')},
    );

    my $img_path = $self->router->uri_for(
        image   => 'song_histogram',
        song_id => $song_id,
    );

    my $uri = $req->uri;
    $uri->path($img_path);

    $f = $f->process(
        Template::Refine::Processor::Rule->new(
            selector => Template::Refine::Processor::Rule::Select::CSS->new(
                pattern => 'img.histogram_img',
            ),
            transformer => Template::Refine::Processor::Rule::Transform::Replace->new(
                replacement => sub {
                    my $node = shift;
                    $node->setAttribute(
                        'src' => "$uri",
                    );
                    return $node;
                },
            ),
        ),
        simple_replace {
            my $node = shift;
            replace_text $node, "Song $song_id";
        } '//p',
    );

    return $f->fragment;
}

1;


__DATA__
__[index]__
<h1>Summary of all sessions</h1>
<div id="histograms">
  The histograms go here.
</div>
__[one_histogram]__
<div class="histogram">
<img class="histogram_img" src="" />
<p class="histogram_label">The label goes here</p>
</div>
