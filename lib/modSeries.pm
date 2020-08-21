use strict;

package modSeries;
use lib::abs -soft => qw(. lib);
use Moo;
with 'MooX::Singleton';
use modData;

sub fetch {
    my ( $self, $value ) = @_;
    my $stmt = qq(select id,max_episodes from series 
                where program_id=$program_id and series_number=$value);
    return $db->fetch_row($stmt);
} ## end sub fetch

sub set {
    my ( $self, $new_val ) = @_;
    unless ( defined $new_val ) {
        $new_val = $scr->number( "Program <B>$program</B> - which series", 1 );
    }
    return 1 unless defined $new_val;
    return 0 if $new_val == $series;
    $max_episode = -1;

    # Check if value exists
    my $result = $self->fetch($new_val);
    my $max_episodes;
    unless ( defined $result ) {

        # Record does not exist
        $max_episodes
            = $scr->number(
            sprintf( "How many <B>episodes</B> in <B>%s-s%2.2d</B>", $program, $new_val ), 0 );
        return 1 unless defined $max_episodes;
        $max_episode = $max_episodes;
        $db->exec(
            qq(insert into series (program_id,series_number,max_episodes)
                values($program_id,$new_val,$max_episode))
        );
        $result = $self->fetch($new_val);
    } ## end unless ( defined $result )
    $series_id   = $result->{id};
    $max_episode = $result->{max_episodes};
    $series      = $new_val;
    $episode     = -1;
    $section     = -1;
    return 0;
} ## end sub set
1;
