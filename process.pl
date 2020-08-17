#!/usr/bin/env perl
use strict;
use lib::abs -soft => qw(. lib);
use modDB;
use modData;
use modRawData;
use modFileHandler;
use modProgram;
use modSeries;
use modEpisode;
use modSection;

# Screen
use modScreen;
my $testOrProd = "PROD";
use experimental qw(switch );
$db       = modDB->instance( level => "$testOrProd" );
$scr      = modScreen->instance();                       #$testOrProd="TEST";
$oSection = modSection->instance();
$oRawData = modRawData->instance();

my $mp4      = modFileHandler->instance();
my $oProgram = modProgram->instance();
my $oSeries  = modSeries->instance();
my $oEpisode = modEpisode->instance();
my $status;

sub s01_initialise {

    # Enable database
    # Enable screen handler
    # Fetch eligible files from the database
    # Read mp4 files from the filesystem
    $mp4->fetch();

    # Add new mp4 files to rhe database
    if ( $oRawData->add_new() > 0 ) {

        # New files, so re-fetch from the raw_files table
        $oRawData->fetch();
    }

    # These are singletons - first initalisation sets up links to other objects
    # $status = $sect->skip_over_processed();
    $status = $oRawData->skip_over_files_with_sections();
} ## end sub s01_initialise

sub s02_process {

    my $video_length;
    my $result;
    my $start_time;
    my $end_time;
    my $action;
    my $msg;
    my @p;

    $action = " ";
ALL: while ( $action ne "\e" ) {
        $scr->print_status(
            $oRawData->{name}, $program,
            sprintf( "%2.2d", $series ),
            sprintf( "%2.2d", $episode ),
            sprintf( "%2.2d", $section+1 )
        );

        # @p   = ( '??', '??', '??' );
        $msg = "&Program";
        if ( $program ne '#' ) {

            # $p[0] = $program;
            $msg = "$msg &Series";
        }
        if ( $series != -1 ) {

            # $p[1] = sprintf( "%2.2d", $series );
            $msg = "$msg &Episode";
        }
        if ( $episode != -1 ) {

            # $p[2] = sprintf( "%2.2d", $episode );
            $msg = "$msg &section";
        }
        $msg = "$msg &File";

        # $scr->at(
        #     -3, 0,
        #     $scr->color_it(
        #         sprintf( "<B>%s</B>: <B>%s</B>-S<B>%s</B>E<B>%s</B>", $oRawData->{name}, @p )
        #     )
        # );
        $action = $scr->get_char($msg);
        given ($action) {
            when ('F') {
                my $fmsg = "";
                if   ( $rsection_count == 0 ) { $fmsg = "&Delete"; }
                else                          { $fmsg = "&Forward"; }
                $fmsg = "$fmsg &Previous &Search";
                given ( $scr->get_char($fmsg) ) {
                    when ('F') {
                        $oRawData->next();
                    }
                    when ('P') {
                        $oRawData->prev();
                    }
                } ## end given
            } ## end when ('F')
            when ('P') {
                next unless $oProgram->set() == 0;
            }
            when ('S') {
                next unless $oSeries->set() == 0;
            }
            when ('E') {
                next unless $oEpisode->set() == 0;
            }
            when ('s') {
                next unless $oSection->set() == 0;
            }
        } ## end given
    } ## end ALL: while ( $action ne "\e" )
} ## end sub s02_process

sub s0_main {
    s01_initialise();
    s02_process();
}
eval {
    # Main process
    s0_main;
};
if ($@) {
    my $buff = $@;
    eval {
        # Rollback
        $db->disconnect(1);
    };
    print "\n$buff\n";
} ## end if ($@)
print "\r\nEnd of run\n\r";
