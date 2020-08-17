use strict;

package modSection;
use lib::abs -soft => qw(. lib);
use Term::ANSIColor qw(colored :constants);
use Moo;
with 'MooX::Singleton';
use modData;
use modTime;
#
has raw_arr     => ( is => 'rw', default => sub { [] } );
has episode_arr => ( is => 'rw', default => sub { [] } );
has outliers    => ( is => 'rw', default => sub { [] } );

=head2 fetch_episode_sections

=cut

sub fetch_episode_sections {
    my ($self) = @_;
    my $stmt = qq(
        select  a.id section_id,a.start_time,a.end_time,a.section_number,
                b.name
         from section a
        left outer join raw_file b on b.id=a.raw_file_id
        where a.episode_id=$episode_id
        order by a.section_number);
    my $result = $db->fetch($stmt);
    $self->episode_arr($result);
    return @{$result};
} ## end sub fetch_episode_sections

=head2 fetch_raw_sections

=cut

sub fetch_raw_sections {
    my ($self) = @_;
    my $stmt = qq(
        select  e.name program_name, d.series_number, c.episode_number,
                b.section_number,b.start_time,b.end_time
            from raw_file a
            inner join section b on b.raw_file_id=a.id
            inner join episode c on c.id =b.episode_id
            inner join series d on d.id=c.series_id
            inner join program e on e.id=d.program_id
        where a.id=$raw_id
        order by b.start_time);
    my $result = $db->fetch($stmt);
    $self->raw_arr($result);
    $rsection_count = @{$result};
} ## end sub fetch_raw_sections

sub fetch_outliers {
    my ($self) = @_;
    my $stmt = qq(select * from outliers where program_name=$program and series=$series
                    order by episode);
    my $result = $db->fetch($stmt);
    $self->outliers($result);
} ## end sub fetch_outliers

sub check_overlap {
    my ( $self, $t1, $t2 ) = @_;
    if ( $t1 ge $t2 ) {
        $scr->get_char( sprintf( "<E>Section %s >= %s </E> &Acknowledge", $t1, $t2 ) );
        return 1;
    }
    my ( $compare_start, $compare_end, $n );
OUTER: while (1) {
    INNER: for ( $n = 0; $n < $rsection_count; $n++ ) {
            $compare_start = $self->{raw_arr}->[$n]->{start_time};
            $compare_end   = $self->{raw_arr}->[$n]->{end_time};

            # Stradles existing start time?
            last OUTER
                if ($t1 lt $compare_start
                and $t2 ge $compare_start );

            # New start time starts in middle of existing section?
            last OUTER if ( $t1 ge $compare_start and $t1 lt $compare_end );
        } ## end INNER: for ( $n = 0; $n < $rsection_count...)
        return 0;
    } ## end OUTER: while (1)
    $scr->display(
        sprintf "</B>%s -S%2.2dE%2.2d Section %2.2d %s %s\n",
        $self->{raw_arr}->[$n]->{program_name},
        $self->{raw_arr}->[$n]->{series_number},
        $self->{raw_arr}->[$n]->{episode_number},
        $self->{raw_arr}->[$n]->{section_number},
        $compare_start,
        $compare_end
    );
    $scr->acknowledge( sprintf( "<E>Section %s - %s overlaps existing section</E>", $t1, $t2 ) );
    return 1;
} ## end sub check_overlap

sub new_section {
    my ( $self, $section_number, $t1, $t2 ) = @_;
    my $stmt = qq{
        insert into section (episode_id,raw_file_id,section_number,start_time,end_time) 
        values ($episode_id,$raw_id,$section_number, '$t1', '$t2')
    };
    $db->exec($stmt);
    $self->fetch_episode_sections($episode_id);
    $self->fetch_raw_sections($raw_id);
    $db->disconnect(0);    # Commit
    $section = $section_number;
} ## end sub new_section

sub print_sections {

    my ($self) = @_;
    my $n;
    my $episode_length = "00:00:00.000";
    my $msg;
    my ( @arr, @prev, @color );

    $scr->display( "-" x 80 );
    @prev = ( ("#") x 4 );
    for ( $n = 0; $n < @{ $self->{episode_arr} }; $n++ ) {
        @arr = (
            sprintf( "%28s", $self->{episode_arr}->[$n]->{name} ),
            sprintf( "%2d",  $self->{episode_arr}->[$n]->{section_number} ),
            $self->{episode_arr}->[$n]->{start_time},
            $self->{episode_arr}->[$n]->{end_time}
        );
        $msg = colored( "Episode", "blue" ) . ": ";
        for ( my $m = 0; $m < 4; $m++ ) {
            if ( $arr[$m] eq $prev[$m] ) {
                $color[$m] = "green";
            }
            else {
                $color[$m] = "yellow";
                $prev[$m]  = $arr[$m];
            }
            $msg = $msg . colored( $arr[$m], $color[$m] ) . " ";
        } ## end for ( my $m = 0; $m < 4...)
        $scr->display($msg);
        $episode_length = timeadd( timediff( $arr[3], $arr[2] ), $episode_length );
    } ## end for ( $n = 0; $n < @{ $self...})
    $scr->display("Length of episode = $episode_length");

#    e.name program_name, d.series_number, c.episode_number, b.section_number,b.start_time,b.end_time
    @prev = ( ('#') x 6 );
    for ( $n = 0; $n < @{ $self->{raw_arr} }; $n++ ) {
        @arr = (
            $self->{raw_arr}->[$n]->{program_name},
            sprintf( "%2d", $self->{raw_arr}->[$n]->{series_number} ),
            sprintf( "%2d", $self->{raw_arr}->[$n]->{episode_number} ),
            sprintf( "%2d", $self->{raw_arr}->[$n]->{section_number} ),
            $self->{raw_arr}->[$n]->{start_time},
            $self->{raw_arr}->[$n]->{end_time}
        );
        $msg = colored( "RawFile", "white" ) . ": ";
        for ( my $m = 0; $m < 6; $m++ ) {
            if ( $arr[$m] eq $prev[$m] ) {
                $color[$m] = "green";
            }
            else {
                $color[$m] = "yellow";
                $prev[$m]  = $arr[$m];
            }
            $msg = $msg . colored( $arr[$m], $color[$m] ) . " ";
        } ## end for ( my $m = 0; $m < 6...)
        $scr->display($msg);
    } ## end for ( $n = 0; $n < @{ $self...})
    if ( @{ $self->{outliers} } < 1 ) {
        $scr->display("--- No Outliers ---");
    }
    else {
        for ( $n = 0; $n < @{ $self->{outliers} }; $n++ ) {
            $scr->display(
                sprintf(
                    "OUTLIER: Episode %2.2d Duration %s (Average %s)",
                    $self->{outliers}->[$n]->{episode_number},
                    to_timestamp( $self->{outliers}->[$n]->{duration} ),
                    to_timestamp( $self->{outliers}->[$n]->{average} )
                )
            );
        } ## end for ( $n = 0; $n < @{ $self...})
    } ## end else [ if ( @{ $self->{outliers...}})]
    $scr->display( "-" x 80 );
} ## end sub print_sections

sub set {
    my ($self) = @_;
    my $new_val = $section + 1;
    my $start_time = $scr->get_timestamp( "Start time", "00:00:00.000" );
    my $end_time   = $scr->get_timestamp( "End time",   $video_length );
    return 1 if $self->check_overlap( $start_time, $end_time );
    my $msg = sprintf( "Section %d %s to %s", $new_val, $start_time, $end_time );
    return 1 unless $scr->acknowledge($msg) == 0;
    $self->new_section( $new_val, $start_time, $end_time );
    $self->print_sections();
    return 0;
} ## end sub set
1;
