#!/usr/bin/env perl
use strict;
use lib::abs -soft => qw(. lib);
use Getopt::Std;
use modDB;
use modData;
use modRawData;
use modFileHandler;
use modProgram;
use modSeries;
use modEpisode;
use modSection;
use Getopt::Std;

# Screen
use modScreen;
my $testOrProd = "PROD";
use experimental qw(switch );
my $lengths;

# $scr = modScreen->instance();                       #$testOrProd="TEST";
# # Decide what we want to do
# my $oProgram = modProgram->instance();
# my $oSeries  = modSeries->instance();
# my $oEpisode = modEpisode->instance();
# exit(1) unless $oProgram->set() == 0;
# my $xx = $oSeries->get_possible_series();
# printf("Hello $program ($program_id)\n");
sub fetch_lengths {
    my $stmt = qq(
		select episode_id,section_number,seg_start_ms,seg_end_ms,raw_ms
			from segments
			where program_name = '$program'
			and  series_number = '$series'
			and episode_number = '$episode'
		);
    return $db->fetch($stmt);
} ## end sub fetch_lengths

sub print_meta {
    my $title      = sprintf( "%sS%2.2dE%2.2d", $program, $series, $episode );
    my $episode_id = $lengths->[0]->{episode_id};
    my $header     = qq(;FFMETADATA1
major_brand=isom
minor_version=512
compatible_brands=isomiso2avc1mp41
title=$title
episode_sort=$episode
show=$program
episode_id=$episode_id
season_number=$series
media_type=10
encoder=Lavf58.20.100

);
    printf($header);
    my $chapter  = 0;
    my $start_ms = 0;
    my $wrap     = 0;
    my %chap;

    for ( my $n = 0; $n < @{$lengths}; $n++ ) {

        # printf( ";%d %d (%d)\n",
        #     $lengths->[$n]->{seg_start_ms},
        #     $lengths->[$n]->{seg_end_ms},
        # $lengths->[$n]->{raw_ms} );
        if ( $lengths->[$n]->{seg_start_ms} ne 0 or $wrap eq 0 ) {

            # A real chapter
            $chapter++;
            $chap{$chapter}->{start} = $start_ms;
        } ## end if ( $lengths->[$n]->{...})
        $wrap = 0;
        $start_ms += $lengths->[$n]->{seg_end_ms} - $lengths->[$n]->{seg_start_ms};
        $chap{$chapter}->{end} = $start_ms - 1;
        $wrap = 1 if ( $lengths->[$n]->{raw_ms} eq $lengths->[$n]->{seg_end_ms} );
    } ## end for ( my $n = 0; $n < @...)
    $chap{$chapter}->{end}++;
    for ( my $n = 1; $n <= $chapter; $n++ ) {
        printf(
            "[CHAPTER]\nTIMEBASE=1/1000\nTITLE=%s-%2.2d\nSTART=%d\nEND=%d\n\n",
            $title, $n,
            $chap{$n}->{start},
            $chap{$n}->{end}
        );
    } ## end for ( my $n = 1; $n <= ...)
} ## end sub print_meta

sub init {

    # Get Parameters
    my %opts;
    getopts( 'p:s:e:', \%opts );

    # Initialise database connection
    $db = modDB->instance( level => "$testOrProd" );
    #
    die "Must provide program (-p)" unless exists $opts{'p'};
    $program = $opts{'p'};
    #
    die "Must provide series (-s)" unless exists $opts{'s'};
    $series = $opts{'s'};
    #
    die "Must provide episode (-e)" unless exists $opts{'e'};
    $episode = $opts{'e'};
} ## end sub init
init();
$lengths = fetch_lengths();
print_meta();
