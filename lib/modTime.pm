use strict;

package modTime;
use Exporter;
our @ISA    = 'Exporter';
our @EXPORT = qw(timediff timeadd to_milli to_timestamp);

sub to_milli {
    my ($ts) = @_;
    $ts =~ /(..):(..):(..\....)/;
    return ( ( $1 * 60 + $2 ) * 60 + $3 );
}

sub to_timestamp {
    my ($milli) = @_;
    my @arr;
    my $w1 = int($milli);
    $arr[3] = $milli - $w1;
    $arr[0] = int( $w1 / 3600 );
    $w1 -= ( $arr[0] * 3600 );
    $arr[1] = int( $w1 / 60 );
    $w1 -= ( $arr[1] * 60 );
    $arr[2] = $w1;
    return sprintf( "%2.2d:%2.2d:%2.2d.%3.3d", @arr );
} ## end sub to_timestamp

sub timediff {
    my ( $t1, $t2 ) = @_;
    my $delta = to_milli($t1) - to_milli($t2);
    return to_timestamp($delta);
}

sub timeadd {
    my ( $t1, $t2 ) = @_;
    my $delta = to_milli($t1) + to_milli($t2);
    return to_timestamp($delta);
}
