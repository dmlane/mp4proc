#!/usr/bin/env perl
use strict;
use Sys::Hostname;
use Log::Log4perl qw(get_logger);
use lib::abs -soft => qw(. lib);
use modDB;
use Cwd 'abs_path';
use modFileHandler;

# Screen
use modScreen;
my $testOrProd = "PROD";
use experimental qw(switch );
my $db               = modDB->instance( level => "$testOrProd" );
my $host             = hostname;
my $scriptdir        = abs_path($0);
my $script_err_count = 0;

$scriptdir =~ s/\/[^\/]*$//;
Log::Log4perl->init( $scriptdir . "/log4j.conf" );
my $logger = get_logger("jobsched");
$logger->info("Start of run");

sub ffmpeg_version {
    my $res = `ffmpeg -version`;
    $res =~ /ffmpeg version ([0-9\.]*).*/;
    return $1;
}

sub run_script {
    my $script = shift;
    $logger->info("Running script:");
    $logger->info($script);
    my $output = qx/$script/;
    return 1 unless defined $output;
    $logger->info($output);
    return 0 if ( $output =~ /\+\+\+\+\+\+\+\+\+\+/ );
    $script_err_count++;
    $logger->logdie("Too many script failures") if $script_err_count > 9;
    return 1;
} ## end sub run_script

sub get_section_name {
    my $p = shift;
    return sprintf( "%s_S%2.2dE%2.2d-%2.2d.mp4",
        $p->{program_name}, $p->{series_number}, $p->{episode_number}, $p->{section_number} );
}

sub process_section {
    my $episode_id = shift;
    my $err_count  = 0;
    my $ok_count   = 0;
    my $info       = $db->fetch(
        qq(
        select  a.name program_name,b.series_number,c.episode_number,d.id section_id,
                d.section_number,d.start_time,d.end_time,d.status,
                e.name file_name,e.video_length
        from program a 
             left outer join series b on b.program_id = a.id 
             left outer join episode c on c.series_id = b.id 
             left outer join section d on d.episode_id = c.id 
             left outer join raw_file e on e.id = d.raw_file_id
             where c.id=$episode_id and d.status=0;
        )
    );

    # Make sure we process all sections and episode on same machine
    #  ......
    $db->exec(qq(update episode set host='$host' where id=$episode_id));
    for ( my $n = 0; $n < @{$info}; $n++ ) {
        my $output_file = get_section_name( $info->[$n] );
        if (run_script(
                qq($scriptdir/split_video.sh -i $info->[$n]->{file_name} -f $info->[$n]->{start_time} -t $info->[$n]->{end_time} -l $info->[$n]->{video_length} $output_file )
            ) == 0
            )
        {
            $db->exec(qq(update section set status=1 where id=$info->[$n]->{section_id}));
            $ok_count++;
            next;
        } ## end if ( run_script(...))
        $err_count++;
    } ## end for ( my $n = 0; $n < @...)
    if ( $err_count > 0 ) {
        if ( $ok_count == 0 ) { $db->disconnect(1); }    # Rollback
        return 1;
    }
    $db->disconnect(0);                                  # >1 section OK
    return 0;
} ## end sub process_section

sub process_episode {
    my $episode_id = shift;
    my $ifiles     = "";
    my $fversion   = ffmpeg_version();

    # Process sections
    my $status = process_section($episode_id);
    return 1 if $status != 0;

    # Get a list of files to process
    my $result = $db->fetch(
        qq  (select episode_id, section_number, start_time, end_time,
                video_length,file_name,program_name,series_number,episode_number
                from videos where episode_id=$episode_id
                order by section_number)
    );
    for ( my $n = 0; $n < @{$result}; $n++ ) {
        $ifiles = $ifiles . " -i " . get_section_name( $result->[$n] );
    }
    my $ofile = sprintf(
        "%s_S%2.2dE%2.2d.mp4",
        $result->[0]->{program_name},
        $result->[0]->{series_number},
        $result->[0]->{episode_number}
    );
    if (run_script(
            qq($scriptdir/merge.sh $ifiles -p $result->[0]->{program_name} -S $result->[0]->{series_number} -e $result->[0]->{episode_number} $ofile )
        ) == 0
        )
    {
        $db->exec(qq(update episode set status=1,ffmpeg_version='$fversion' where id=$episode_id));
    } ## end if ( run_script(...))
    $db->disconnect(0);
} ## end sub process_episode
my $last_key = 0;
our $restarting = 0;

sub lock_episode {
    my ( $possible, $result, $id );

    # Stupid MariaDB doesn't have skip locked, so we have to fudge it.
    #--> get next 3 records and try to lock each 1 in turn
    my $num_to_do = $db->fetch_number(
        qq(
        select count(*) from episode where status<1 and coalesce(host,'$host')='$host'
        )
    );
    $logger->debug("$num_to_do records left to process");
    if ( $num_to_do < 1 ) {
        $logger->debug("No new records");
        $restarting = 1;
        return;
    }
    $possible = $db->fetch(
        qq(select id from episode where status<1 and coalesce(host,'$host')='$host' and id > $last_key
            order by id limit 3
            )
    );
    for ( my $n = 0; $n < 3; $n++ ) {
        $possible->[$n]->{id} = -1 unless defined $possible->[$n]->{id};
    }
    $logger->debug(
        sprintf(
            "Selected following possible episode ids %d, %d and %d",
            $possible->[0]->{id},
            $possible->[1]->{id},
            $possible->[2]->{id}
        )
    );
    for ( my $n = 0; $n < @{$possible}; $n++ ) {
        $id = $possible->[$n]->{id};
        next if $id < 1;
        $result = $db->fetch_number(qq(select id from episode where id=$id for update nowait));
        if ( defined $result ) {
            $logger->debug("Locked and selected episode_id <$id>");
            $last_key = $id;
            return $id;
        }
    } ## end for ( my $n = 0; $n < @...)
    return;
} ## end sub lock_episode

#---------------------------------------------------------------------------------
my $episode_id;
my $section_id;
my $counter = 0;

#sub ctrl_c {
#    $SIG{INT} = \&ctrl_c;
#    $logger->info("Launctl stop detected - closing after current action ......");
#    $restarting = 1;
#}
#$SIG{INT} = \&ctrl_c;
my $flag = "/tmp/mp4proc.stop";
while ( $counter < 30 ) {
    if ( -e $flag ) {
        unlink $flag;
		$logger->info("$flag found, so exiting");
        exit(0);
    }
    $counter++;

    # Start transaction
    $db->connect();    # Start transaction

    # Get next job entry ..........
    $episode_id = lock_episode();
    $logger->info("restarting=$restarting");
    last if $restarting > 0;
    if ( defined $episode_id ) {
        $counter = 0;
        process_episode($episode_id);
        next;
    }
    $db->disconnect(0);    # Commit
    sleep 60;
} ## end while ( $counter < 30 )
$logger->info("Successful end of run ++++++++++");
exit(0);
