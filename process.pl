#!/usr/bin/env perl
use strict;
use File::Basename;
use Term::Menus;
use Term::ReadKey;
use Term::ANSIColor qw(colored :constants);
use MP4::Info;
use Const::Fast;
use lib::abs qw(lib);

#use vidDB 'PROD';
use vidDB 'TEST';
use vidGlobals;
use vidScreen;
use vidSection;
use feature 'switch';

no warnings 'experimental::smartmatch';

# Global variables (See also vidGlobals.pm)
my $raw_files;    # All frecords from videos.raw_file
my $raw_sub;      # Current subscript to raw_files
my @mp4_files;    # All files in $mp4_dir
my $high_values = "ZZZZ";
my %status;       # Current status of process
my $sectHandler;

#=====================================================================
sub cc {
    my ( $p1, $p2 ) = @_;
    my $col;
    $col = ( $p1 eq $p2 ) ? 'green' : 'yellow';
    return colored( $p1, $col );
}

sub link_file {
    my ( $target_name, $link_name ) = @_;
    unlink $link_name if -e $link_name;
    system("ln $target_name $link_name") == 0
        or die "Cannot ln $target_name to $link_name";
}

=head2  skip_over_files_with_sections
Place the cursor on the first record without sections and initialise $status
=cut

sub skip_over_files_with_sections {

    # Skip over files with sections
    for ( $raw_sub = 0; $raw_sub < @{$raw_files}; $raw_sub++ ) {
        last if $raw_files->[$raw_sub]->{section_count} == 0;
    }

    # Fetch the last settings
    {
        my $prev_sections = $db->get_sections_of_raw_file( $raw_files->[ $raw_sub - 1 ]->{file} );
        if ( @{$prev_sections} > 0 ) {
            my $ptr = \%{ $prev_sections->[-1] };
            $status{program}      = $ptr->{program_name};
            $status{series}       = $ptr->{series_number};
            $status{episode}      = $ptr->{episode_number};
            $status{section}      = $ptr->{section_number};
            $status{max_episodes} = $db->get_max_episodes( $status{program}, $status{series} );
        }
    }
}

#=====================================================================

=head2  s01_initialise
Initialise for this run
=cut

sub s01_initialise {

    # Auto-flush output (don't wait for \n)
    $| = 1;

    # Fetch new files from the database - there may be a delay if the server is asleep
    $db          = new vidDB();
    $sectHandler = new vidSection($db);
    printf "\nFetching raw_files from database ........";
    $raw_files = $db->fetch_new_files();
    printf( " %d files loaded\n", scalar @{$raw_files} );

    # Fetch files from file-system
    printf "\nFetching unix_files from $mp4_dir ........";
    @mp4_files = glob( $mp4_dir . '/*.mp4' );
    if ( @mp4_files == 0 ) {
        unless ( -d $mp4_dir ) {
            printf "Can't find $mp4_dir\n";
            die "Check network";
        }
    }
    printf( " %d files loaded\n", scalar @mp4_files );
}

=head2  s021_preprocess
Prepare for this run.
=cut

sub s021_preprocess {
    $raw_sub = 0;
    my $info;
    my %val;

    # Add high values to arrays so that we can match more easily
    push @{$raw_files},
        {
        file          => $high_values,
        section_count => 99,
        video_length  => "00:00:00.000",
        raw_status    => 0
        };
    push @mp4_files, $high_values;
    $db->connect();

    # Introduce new records to the database .......
    for ( my $usub = 0; $usub < @{$raw_files}; $usub++ ) {

        # Remove the directory part of the file-names
        $val{file} = basename $mp4_files[$usub];

        # Skip over raw_file records which don't have equivalent files
        while ( $raw_files->[$raw_sub]->{file} lt $val{file} ) {
            $raw_sub++;
        }

        # If raw_file match exists, we don't need to do anything
        next if $raw_files->[$raw_sub]->{file} eq $val{file};

        # A new file to add, so get the video_length from the mp4
        $info = get_mp4info( $raw_files->[$raw_sub]->{file} );
        $val{video_length} = sprintf(
            "%02d:%02d:%02d.%003d",
            int( $info->{MM} / 60 ),
            int( $info->{MM} % 60 ),
            $info->{SS}, $info->{MS}
        );

        # Database can't do a version sort, so split the key fields so it can
        if ( $val{file} =~ m/^([^_]*_[^_]*_[^_]*)\./ ) {
            $val{key1} = $1;
            $val{key2} = 0;
        }
        else {
            ( $val{key1}, $val{key2} ) = ( $val{file} =~ /^(.*)_(\d+)\..*$/ );
        }

        #$db->addfile(%val);
    }
    $db->disconnect();
}

=head2  s02211_display_sections
Display information relevant to current situation.
=cut

sub s02211_display_sections {
    my ( $dsub, $color ) = @_;
    return 0 if $dsub < 1;
    my $ptr;
    my $rec   = $db->get_sections_of_raw_file( $raw_files->[$dsub]->{file} );
    my $error = "";
    my $msg;
    if ( @{$rec} < 1 ) {
        printf( "%s\n", colored( "No data", $color ) );
        return 0;
    }
    if ( $raw_files->[$dsub]->{file} eq $high_values ) {
        printf( "%s\n", colored( "-- End of Data --", $color ) );
        return 0;
    }

    # Check overlaps
    #my %prev = { start_time => -2, end_time => -1 };
    my $prev = \%{ $rec->[0] };
    for ( my $n = 1; $n < @{$rec}; $n++ ) {
        $error = "";
        $ptr   = \%{ $rec->[$n] };
        if (   $ptr->{start_time} < $prev->{end_time}
            or $ptr->{start_time} >= $ptr->{end_time} )
        {
            $error = "Overlap";
        }
        $msg = sprintf(
            "%5d %21s_%2d %s %2d %2d %d %s %s",
            $ptr->{section_id},     $ptr->{k1},
            $ptr->{k2},             $ptr->{program_name},
            $ptr->{series_number},  $ptr->{episode_number},
            $ptr->{section_number}, timestamp( $ptr->{start_time} ),
            timestamp( $ptr->{end_time} )
        );
        printf( "%s %s\n", colored( $msg, $color ), colored( $error, 'red' ) );
        $prev = \%{ $rec->[$n] };
    }
    return @{$rec};
}

=head2  s0221_display_context
Display information relevant to current situation.
=cut

sub s0221_display_context {
    my ( $dsub, $context_type ) = @_;
    my $ignore;
    my $result;
    if ( $context_type == 0 ) {
        $ignore = s02211_display_sections( $dsub - 1, 'blue' );
        $result = s02211_display_sections( $dsub,     'bright_yellow on_blue' );
        $ignore = s02211_display_sections( $dsub + 1, 'blue' );
    }
    return $result;
}

=head2  s022_display_episodes
Display information about current series - including misordering and outliers.
=cut

sub s0222_display_episodes {

    my ( $program_name, $series_number ) = @_;
    my $esub = 1;
    my $ptr;
    my $msg;
    my $color;

    unless ( defined $program_name and defined $series_number ) {
        printf( "Program_name '%s' or series_number '%s' not defined\n",
            $program_name, $series_number );
        return;
    }
    my $episodes = $db->get_series_episodes( $program_name, $series_number );
    for ( my $n = 0; $n < @{$episodes}; $n++ ) {
        $ptr = \%{ $episodes->[$n] };
        $msg = sprintf(
            "%s-s%2.2d-e%2.2d %s",
            $ptr->{program_name},   $ptr->{series_number},
            $ptr->{episode_number}, timestamp( $ptr->{duration} )
        );
        $color = "green";
        if ( $ptr->{episode_number} != $esub ) {
            printf( "%s\n", colored( "." x 40, "white" ) );
            $color = "yellow";
        }
        $esub = $ptr->{episode_number} + 1;
        if ( $ptr->{outlier} eq "Outlier" ) {
            printf( "%s %s\n", colored( $msg, $color ), colored( "<<Outlier>>", "Red" ) );
        }
        else {
            printf( "%s\n", colored( $msg, $color ) );
        }
    }
}

sub s02231_get_program {
    my $programs    = $db->get_programs();
    my $new_program = "*New*";
    my @menu;
    for ( my $n = 0; $n < @{$programs}; $n++ ) {
        push @menu, $programs->[$n]->{name};
    }
    push @menu, $new_program;
    my $selection = &pick( \@menu, "Choose a program:" );
    if ( $selection eq $new_program ) {
        printf "What is the program name? ";
        $selection = <STDIN>;
        chomp $selection;
    }
    $selection = "" if $selection eq "]quit[";
    return $selection;
}

sub s02232_get_series {
    my ($default_series) = @_;
    my $series
        = get_integer( "Which series number of " . colored( $status{program}, "yellow" ) . "? ",
        1 );

    # Check if we already know how many episodes there are.
    my $max_episodes = $db->get_max_episodes( $status{program}, $series );
    unless ( defined $max_episodes ) {
        $max_episodes
            = get_integer( "How many episodes are in "
                . colored( $status{program}, "yellow" )
                . " series "
                . colored( $series, "yellow" )
                . "? (0 quits) " );
        $db->set_max_episodes( $status{program}, $series, $max_episodes ) unless $max_episodes == 0;
    }
    $status{max_episodes} = $max_episodes;
    $status{series}       = $series;
}

sub s02233_goto {

    my ( $program_name, $series_number ) = @_;
    my $esub = 1;
    my $ptr;
    my $msg;
    my $color;
    my @arr;
    my $width = 0;

    unless ( defined $program_name and defined $series_number ) {
        printf( "Program_name '%s' or series_number '%s' not defined\n",
            $program_name, $series_number );
        return;
    }
    my $episodes = $db->get_series_episode_sections( $program_name, $series_number );
    my $prev     = \%{ $episodes->[0] };
    for ( my $n = 0; $n < @{$episodes}; $n++ ) {
        my $w = length( $episodes->[$n]->{file_name} );
        $width = $w if $w > $width;
    }
    for ( my $n = 0; $n < @{$episodes}; $n++ ) {
        $ptr = \%{ $episodes->[$n] };
        my $xx = cc( $ptr->{episode_number}, $prev->{episode_number} );
        $msg = sprintf(
            "%s: %s-s%s-e%s-%s %s %s <%3.3d>",
            cc( pad( $ptr->{file_name}, $width, ' ' ), pad( $prev->{file_name}, $width, ' ' ) ),
            $ptr->{program_name},
            pad( $series_number, 2, '0' ),
            cc( pad( $ptr->{episode_number}, 2, '0' ), pad( $prev->{episode_number}, 2, '0' ) ),
            cc( pad( $ptr->{section_number}, 2, '0' ), pad( $prev->{section_number}, 2, '0' ) ),
            $ptr->{start_time},
            $ptr->{end_time},
            $n
        );
        push @arr, $msg;
        $prev = $ptr;
    }
    push @arr, "GoTo first empty file <9999>";
    my $selection = &pick( \@arr, "Choose an entry:" );
    $selection =~ m/^.*<(\d*)>$/;
    my $selsub = int($1);
    if ( $selsub == 9999 ) {
        skip_over_files_with_sections();
        return;
    }
    my $curr;
    my $search = \%{ $episodes->[$selsub] };
    for ( my $n = 0; $n < @{$raw_files}; $n++ ) {
        $curr = \%{ $raw_files->[$n] };
        if ( $curr->{file} eq $search->{file_name} ) {
            $raw_sub = $n;
            return;
        }
    }
    printf("\n$selection\n");
}

sub s02234_section {
    my @times;
    my $ichar;
    my $new_values;
    $status{section}
        = get_integer( "Section number", $status{section} + 1 );
    @times = get_start_stop_times( \%status );
    return if @times == 0;    # Back was selected
    $status{start_time} = $times[0];
    $status{end_time}   = $times[1];

    if ( $db->add_section( 0, %status ) == 1 ) {
        while (1) {
            $ichar
                = $scr->get_char(
                sprintf "Program %s Series %s Episode %s Section %s already exists - replace?",
                $status{program}, $status{series}, $status{episode}, $status{section} );
            last if ( $ichar =~ "[yYnN]" );
        }
        return (1) if $ichar =~ "[nN]";
        die "Cannot insert section on 2nd attempt"
            if $db->add_section( 1, %status ) == 1;
    }
}

sub s0223_prompt {

    my ($args) = @_;
    my @order
        = ( "quit", "goto", "back", "file", "delete", "program", "series", "episode", "section" );
    my $m   = "";
    my $sep = "";
    my $msg = "";
    my $result;
    my $choice;
    my %opts = (
        back    => "&Back",
        delete  => "&Delete",
        episode => "&Episode",
        file    => "&File",
        goto    => "&GoTo",
        program => "&Program",
        quit    => "&Quit",
        section => "&section",
        series  => "&Series",
    );

    foreach my $key (@order) {
        unless ( defined $args->{$key} ) {
            $m   = $m . $sep . $opts{$key};
            $sep = ", ";
        }
    }
    $msg = "";
    foreach my $bits ( split( "&", $m ) ) {
        $msg
            = $msg . colored( substr( $bits, 0, 1 ), "yellow underline" ) . substr( $bits, 1 );
        $choice = $choice . substr( $bits, 0, 1 );
    }
    my $c = "=";
    printf($msg);
    ReadMode('cbreak');
    while ( index( $choice, $c ) == -1 ) {
        $c = ReadKey(0);
    }
    ReadMode('normal');
    given ($c) {
        when ('B') {
            $raw_sub--;
        }
        when ('F') {
            $raw_sub++;
        }
        when ('G') {
            s02233_goto( $status{program}, $status{series} );
        }
        when ('P') {
            my $res = s02231_get_program();
            $status{program} = $res unless $res eq "";
        }
        when ('S') {
            s02232_get_series();
            $status{episode} = 1;
        }
        when ('E') {
            $result = get_integer( "Which episode number? ", $status{episode} + 1 );
            if ( $result > $status{max_episodes} ) {
                $status{episode} = $result
                    if get_yn("Episode $result > $status{max_episodes} - override?") eq "y";
                $sectHandler->change_episode( $status{program}, $status{series}, $status{episode} );
            }
        }
        when ('D') {
            my $ichar = get_yn("Are you sure you want to delete $status{file}?");
            if ( $ichar eq "y" ) {
                my $fn = "$mp4_dir/$status{file}";
                rename $fn, $fn . '.remove' or die "Failed to rename $fn to $fn.remove";
                $db->delete_file( $status{file} );
                splice( @{$raw_files}, $raw_sub, 1 );
            }
        }
        when ('s') {
            s02234_section();
        }
        when ('Q') {
            return 1;
        }
    }
    return 0;
}

# =head2  s022_process_files
# Process eligible files.
# =cut
sub s022_process_files {

    # my $prev = { file => "0000", video_length => "00:00:00.000", raw_status => 0 };
    my $curr;
    my $section_count;
    my $active_file = "";
    my %opt;
    my $link_name = "/tmp/dummy.DoesNotExist";

    $raw_sub = 0;
    %status  = ();
    skip_over_files_with_sections();

    # We are pointing at a record which has no sections yet
    # Process each subsequent file (don't forget there's a dummy record at the end)
    while (1) {
        $raw_sub = 0                 if $raw_sub < 0;
        $raw_sub = @{$raw_files} - 1 if $raw_sub >= @{$raw_files};
        $curr    = \%{ $raw_files->[$raw_sub] };
        if ( $curr->{file} ne $high_values and $curr->{file} ne $active_file ) {

            # Link the file so that avidemux can find it easily
            $link_name = "$pdir/$curr->{file}";
            link_file( "$mp4_dir/$curr->{file}", $link_name );
            $active_file = $curr->{file};
        }
        $status{file} = $active_file;
        s0222_display_episodes( $status{program}, $status{series} );
        %opt           = ();
        $section_count = s0221_display_context( $raw_sub, 0 );
        printf(
            "%s\n",
            colored(
                sprintf(
                    "%s: %s %d %d/%d %d",
                    $status{file},    $status{program},      $status{series},
                    $status{episode}, $status{max_episodes}, $status{section}
                ),
                "magenta"
            )
        );
        if ( $section_count > 0 ) {
            $opt{delete} = "";    # Cannot delete file with sections
        }
        else {
            $opt{file} = "";      # Cannot go to next file if no sections in this
        }
        $opt{series}  = "" unless ( defined $status{program} );
        $opt{episode} = "" unless ( defined $status{series} );
        $opt{section} = "" unless ( defined $status{episode} );
        last if ( s0223_prompt( \%opt ) != 0 );
    }
    unlink $link_name if -e $link_name;
    printf "\nBye\n";
}

=head2  s02_process
Control the processing.
=cut

sub s02_process {

    # Prepare for this run
    s021_preprocess();

    # Process new files
    s022_process_files();
}

=head2  main
Entry point.
=cut

sub s0_main {
    s01_initialise();    # Set the initial state - return snon-zero if error
    s02_process();       # Control processing
}

# -----
s0_main();

#=========================== POD ============================#

=head1 NAME

  identify.pl - Identify sections of videos. 

=cut
