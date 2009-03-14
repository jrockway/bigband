package BigBand::Script::SessionSummary;

use Moose;
use BigBand;

use 5.010;

with 'BigBand::Script::WithKioku';

sub run {
    my $self = shift;
    my $kioku = $self->kioku;

    my $scope = $kioku->new_scope;
    my @roots;
    say "Scanning for sessions...";

    my $all = $kioku->backend->all_entries;
    while( my $chunk = $all->next ){
        entry: for my $id (@$chunk) {
            my $entry = $kioku->lookup($id->id);
            next entry unless blessed $entry && $entry->isa('BigBand::Sample');
            push @roots, $entry if !$entry->has_previous_sample;
        }
    }

    say scalar @roots, " sessions recorded.";
    for my $root (sort { $a->sample_taken <=> $b->sample_taken } @roots){
        my %seen_songs;
        my $time = 0;
        my $cur = $root;
        do {
            $time += $cur->duration;
            $seen_songs{$cur->song_id}++;
        } while( $cur = $cur->next_sample );

        printf(
            "  %s: %s songs played (%s seconds)\n",
            $root->sample_taken,
            scalar keys %seen_songs,
            $time / 1000,
        );
    }
}

1;
