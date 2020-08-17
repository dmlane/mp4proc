use strict;

package modEpisode;
use lib::abs -soft => qw(. lib);
use Moo;
with 'MooX::Singleton';
use modData;

# has section => ( is => 'ro', default => modSection->instance() );
# Class members
# has max_section => ( is => 'rw', default => 0 );
# --
sub fetch {
    my ( $self, $value ) = @_;
    my $stmt = qq(select id,episode_number from episode 
                where series_id=$series_id and episode_number=$value);
    return $db->fetch_row($stmt);
} ## end sub fetch

sub choose_existing_action {

    # Already exists - choose what to do .........
    my ( $self, $new_val ) = @_;
    my $res = $scr->get_char("&Append or &Replace episode");
    return 0 if $res eq chr(27);
    return 1 if $res eq "A";

    # return 0 unless defined $action;
    # return 1 if ( $action eq $action_list[0] );
    $db->exec(
        qq(update raw_data set status=0 where id in 
            (select raw_file_id from section where id=$series_id)
    )
        );
    $db->exec(
        "delete from episode 
            where series_id=$series_id and episode_number=$new_val"
    );
    return 2;
} ## end sub choose_existing_action

sub set {
    my ( $self, $new_val ) = @_;
    unless ( defined $new_val ) {
        $new_val = $scr->number(
            sprintf( "Program <B>%s-S%2.2d-</B> - which episode", $program, $series ), 1 );
    }
    return 0 if $new_val == $episode;
    if ( $new_val < 1 or $new_val > $max_episode ) {
        $scr->acknowledge(
            sprintf(
                "Episode must be between <B>1</B> and <B>%d</B> (<E>%d not accepted</E>)",
                $max_episode, $new_val
            )
        );
        return 1;
    } ## end if ( $new_val < 1 or $new_val...)

    # Prevent creation of episodes with no sections (a commit is issued
    # when a section is created )
    $db->disconnect(1);
    $db->connect();

    # Check if value exists
    my $result = $self->fetch($new_val);
    if ( defined $result ) {
        my $action = $self->choose_existing_action($new_val);

        # return 1 if $action == 1;
        if ( $action == 2 ) {
            undef($result);
            $oSection->fetch_raw_sections();
        }
    } ## end if ( defined $result )
    unless ( defined $result ) {

        # Record does not exist
        $db->exec(
            qq(insert into episode (series_id,episode_number)
                values($series_id,$new_val))
        );
        $result = $self->fetch($new_val);
    } ## end unless ( defined $result )
    $episode_id = $result->{id};
    $episode    = $new_val;
    $section    = $oSection->fetch_episode_sections($new_val);
    return 0;
} ## end sub set

sub add_section {
    my ( $self, $start_time, $end_time ) = @_;
    my $section_number = @{ $oSection->{episode_arr} } + 1;

    # Check for overlap with sections on thie file
    return 1 if $oSection->check_overlap( $start_time, $end_time ) == 1;
    $oSection->new_section( $section_number, $start_time, $end_time );
} ## end sub add_section
1;
