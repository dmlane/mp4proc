#!/usr/bin/env perl
use strict;
use strict;
use lib::abs -soft => qw(. lib);
use modDB;
use Cwd 'abs_path';
use Sys::Hostname;
use modFileHandler;

# Screen
use modScreen;
my $testOrProd = "PROD";
use experimental qw(switch );
my $db        = modDB->instance( level => "$testOrProd" );
my $host      = hostname;
my $scriptdir = abs_path($0);

$scriptdir =~ s/\/[^\/]*$//;

sub run_script {
    my $script = shift;
    system($script);
    if ( $? == -1 ) {
        die "failed to execute: $!\n";
    }
    elsif ( $? & 127 ) {
        printf "child died with signal %d, %s coredump\n",
            ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
        return 1;
    }
    else {
        printf "child exited with value %d\n", $? >> 8;
        return 1;
    }
    return 0;
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
        qq(select  section_id, section_number, start_time, end_time,
    		video_length,file_name,program_name,series_number,episode_number
    		from videos
    		where episode_id=$episode_id and status < 1
    		)
    );

    # Make sure we process on same machineget_section_name($info->[$n]);
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
        if   ( $ok_count > 0 ) { $db->disconnect(0); }    # >1 section OK
        else                   { $db->disconnect(1); }    # Rollback
        return 1;
    }
    return 0;
} ## end sub process_section

sub process_episode {
    my $episode_id = shift;
    my $ifiles     = "";

    # Process sections
    my $status = process_section($episode_id);
    return 1 if $status != 0;

    # Get a list of files to process
    my $result = $db->fetch(
        qq	(select episode_id, section_number, start_time, end_time,
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
            qq($scriptdir/merge.sh $ifiles -p $result->[0]->{program_name} -S $result->[0]->{series_number} -e $result->[0]->{episode_number} )
        ) == 0
        )
    {
        $db->exec(qq(update episode set status=1 where episode_id=$episode_id));
    } ## end if ( run_script(...))
    $db->disconnect(0);
} ## end sub process_episode

sub lock_episode {
    my ( $possible, $result, $id );

    # Stupid MariaDB doesn't have skip locked, so we have to fudge it.
    #--> get next 3 records and try to lock each 1 in turn
    $possible = $db->fetch(
        qq(select id from episode where status<1 and coalesce(host,'$host')
    		order by id limit 3
    		)
    );
    for ( my $n = 0; $n < @{$possible}; $n++ ) {
        $id     = $possible->[$n]->{id};
        $result = $db->fetch_number(qq(select id from episode where id=$id for update nowait));
        return $id if ( defined $result );
    }
    return;
} ## end sub lock_episode

#---------------------------------------------------------------------------------
my $episode_id;
my $section_id;
my $counter = 0;
while ( $counter < 30 ) {
    $counter++;

    # Start transaction
    $db->connect();    # Start transaction

    # Get next job entry ..........
    $episode_id = lock_episode();
    if ( defined $episode_id ) {
        $counter = 0;
        process_episode($episode_id);
        next;
    }
    $db->disconnect(0);    # Commit
    sleep 60;
} ## end while ( $counter < 30 )
