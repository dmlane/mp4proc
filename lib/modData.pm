use strict;

package modData;
use lib::abs -soft => qw(. lib);

#use modDB;
#use modScreen;
use Exporter;
our @ISA = 'Exporter';
our @EXPORT
    = qw($db $scr $oSection $oFileHandler $oRawData $program $program_id $series $series_id $max_episode $episode $episode_id $raw_id $section $video_length $rsection_count);
our (
    $db,        $scr,         $oFileHandler, $oSection,
    $oRawData,  $program,     $program_id,   $series,
    $series_id, $max_episode, $episode,      $episode_id,
    $raw_id,    $section,     $video_length, $rsection_count
);
our $first_pass;

unless ( defined $first_pass ) {
    $program        = "#";
    $program_id     = -1;
    $series         = -1;
    $series_id      = -1;
    $max_episode    = -1;
    $episode        = -1;
    $episode_id     = -1;
    $raw_id         = -1;
    $section        = -1;
    $rsection_count = -1;
    $first_pass     = 1;
    $video_length   = "00:00:00.000";
} ## end unless ( defined $first_pass)
1;
