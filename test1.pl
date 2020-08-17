#!/usr/bin/env perl
use strict;
use lib::abs -soft => qw(. lib);
use modRawData;
use modFileHandler;
use modProgram;
use modData;
use modSeries;
use modEpisode;
use modSection;
my $testOrProd = "PROD";
my $oProgram   = modProgram->instance();

# The following are already initiated, but get a new handle for testing here
my $oSeries = modSeries->instance();
$oRawData = modRawData->instance();
$oSection = modSection->instance();

$db       = modDB->instance( level => "$testOrProd" );
$scr      = modScreen->instance();

 my $oEpisode  = modEpisode->instance();
my $oSection  = modSection->instance();
my $ts=$scr->get_timestamp ("Give me a time","00:02:00.111");
printf "\n\n$ts\n\n";
exit;
#my $raw_data = modRawData->instance();
# my $db       = modDB->instance();
sub s0_main {
    $oProgram->set("Alias");
    die "undefined" if $oSeries->set(1) == 1;

     $oEpisode->set(1);
     $oEpisode->add_section( "00:00:00.111", "00:01:00.999" );
     $oEpisode->add_section( "00:02:00.111", "00:03:00.999" );
     $oEpisode->add_section( "00:05:00.111", "00:04:00.999" );
    printf("What $program_id $program\n");
} ## end sub s0_main
eval {
    # Main process
    s0_main;
};
if ($@) {
    print "$@";
    eval {
        # Rollback
        $db->disconnect(1);
    }
} ## end if ($@)
print "End of run\n";
