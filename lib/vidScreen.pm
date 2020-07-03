use strict;
{

    package vidScreen;

    # use Exporter;
    use File::Basename;
    use Const::Fast;
    use Clipboard;
    use Exporter;
    our @ISA    = qw(Exporter);
    our @EXPORT = qw(get_integer get_start_stop_times get_timestamp get_yn millisecs pad timestamp);

    const my $ctrlC_value => "#CtrlC-value#";

    sub get_integer {
        my ( $prompt, $default ) = @_;
        my $value = -1;
        while (1) {
            printf "\n$prompt [$default]:";
            $value = <STDIN>;
            chomp $value;
            last if ( length($value) < 1 );
            last if ( $value =~ /^\d+$/ );
        }
        return $default if ( length($value) < 1 );
        return $value;
    }

    sub get_timestamp {
        my ( $prompt, $default_value, $min_time, $max_time ) = @_;
        my $value = "00000000000";
        Clipboard->copy("0000000000");
        select()->flush();
        $SIG{INT} = sub {
            Clipboard->copy($ctrlC_value);
        };
        while (1) {
            printf("\n$prompt [$default_value]:");
            until ( $value =~ /^\d\d:\d\d:\d\d\.\d\d\d$/ ) {
                sleep(1);
                $value = Clipboard->paste;
                $value = $default_value if $value eq $ctrlC_value;
            }
            chomp $value;
            if ( millisecs($value) < millisecs($min_time) ) {
                printf "\nRejected $value < $min_time";
                next;
            }
            if ( millisecs($value) > millisecs($max_time) ) {
                printf "\nRejected $value > $max_time";
                next;
            }
            last;
        }
        $SIG{INT} = 'DEFAULT';
        return $value;
    }

    sub get_start_stop_times {
        my ($status)   = @_;
        my $start_time = $status->{start_time};
        my $end_time   = $status->{end_time};
        my $prompt;
        while (1) {

            # Start time .........
            $start_time
                = get_timestamp( "What is the start time", $start_time, $start_time, $end_time );
            $end_time
                = get_timestamp( "$start_time -> end time", $end_time, $start_time, $end_time );
            my $delta_secs = millisecs($end_time) - millisecs($start_time);
            if ( $delta_secs < 0.000 ) {
                printf("\nStart time cannot be greater than stop time");
                next;
            }
            $prompt = sprintf(
                "Create section %s_s%2.2de%2.2d-%2.2d %s - %s [ynb]? ",
                $status->{program}, $status->{series}, $status->{episode},
                $status->{section}, $start_time,       $end_time
            );
            my $res = get_yn( $prompt, 'bB' );
            return () if ( $res eq "b" );
            return ( $start_time, $end_time ) if $res eq 'y';
        }
    }

    sub get_yn {
        my ( $prompt, $extra ) = @_;
        my $c = 'x';
        printf("\n$prompt");
        ReadMode('cbreak');
        while ( index( "yYnN$extra", $c ) == -1 ) {
            $c = ReadKey(0);
        }
        ReadMode('normal');
        return lc($c);
    }

    sub millisecs {
        my $ts = shift;
        $ts =~ /(..):(..):(..\....)/;
        return ( ( $1 * 60 + $2 ) * 60 + $3 );
    }

    sub pad {
        my ( $string, $width, $pad ) = @_;
        my $result;
        $pad = ' ' unless defined $pad;
        if ( $pad eq ' ' ) {
            return sprintf( "%${width}s", $string );
        }

        #return '0' x ( $width - length $string ) . $string;
        return sprintf( "%${width}.${width}d", $string );
    }

=head2  timestamp
Convert seconds to timestamp
=cut

    sub timestamp {
        my $tsecs = shift;
        my $tmin  = int( $tsecs / 60 );
        $tsecs = $tsecs - ( $tmin * 60 );
        return sprintf( "%2.2d:%2.2d.%3.3d",
            $tmin, int($tsecs), int( ( $tsecs - int($tsecs) ) * 1000 ) );
    }
}
1;
