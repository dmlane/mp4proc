use strict;

package modScreen;

# use Term::Menus;
use Term::Choose;
use Term::Screen;
use Term::ReadKey;
use Term::ANSIColor qw(colored :constants);
use Const::Fast;
use Clipboard;
use lib::abs -soft => qw(. lib);
use Moo;

with 'MooX::Singleton';
const my $escape => chr(27);
has term     => ( is => "rw" );
has lastvals => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    $| = 1;    # Auto-flush output (don't wait for \n)
    $self->term( Term::Screen->new() );
    my @p = ( ('??') x 5 );
    $self->lastvals( \@p );
} ## end sub BUILD

sub print_status {
    my $self = shift;
    my @arr  = @_;
    my $bold;
    $bold = 'bright_yellow';
    my $normal    = 'magenta';
    my @color     = ( ($normal) x 5 );
    my @last_vals = @{ $self->{lastvals} };
    for ( my $n = 0; $n < 5; $n++ ) {
        $color[$n] = $bold unless $last_vals[$n] eq $arr[$n];
    }
    my $msg = sprintf(
        "%s: %s-s%se%s section %s",
        colored( $arr[0], $color[0] ),
        colored( $arr[1], $color[1] ),
        colored( $arr[2], $color[2] ),
        colored( $arr[3], $color[3] ),
        colored( $arr[4], $color[4] )
    );
    $self->lastvals( \@arr );
    $self->at( -3, 0, $msg );
} ## end sub print_status

sub color_it {
    my ( $self, $original ) = @_;
    my $result = "";
    my $colour = 'green';
    my @values = split( /(<\/?.>+)/, $original );
    foreach my $val (@values) {
        next if $val eq "";
        if ( $val eq '<B>' ) {
            $colour = 'yellow';
            next;
        }
        if ( $val eq '<E>' ) {
            $colour = 'red';
            next;
        }
        if ( $val eq '</B>' or $val eq '</E>' ) {
            $colour = 'green';
            next;
        }
        $result = $result . colored( $val, $colour );
    } ## end foreach my $val (@values)
    return $result;
} ## end sub color_it

sub at {
    my ( $self, $row, $col, $string ) = @_;
    my $y = $row;
    $y = $self->{term}->rows() + $row - 1 if $row < 0;
    $self->{term}->at( $y, $col )->clreol()->puts($string);
} ## end sub at

sub prompt {
    my ( $self, $prompt, $type, $default ) = @_;
    my $string = "";
    my $fmt    = "%s: ";
    $fmt = "%s [Default '<B>$default</B>']: " if ( length($default) > 0 );
    my ( $c, $o );
    $self->at( -2, 0, $self->color_it( sprintf( $fmt, $prompt ) ) );
    ReadMode('cbreak');
OUTER: while () {
    INNER: while () {
            $c = ReadKey(0);
            $o = ord($c);
            last INNER if $c eq $escape;
            if ( $o == 127 )    # This should be backspace
            {
                $string = substr( $string, 0, -1 ) if length($string) > 0;
                printf("\b \b");
                next;
            } ## end if ( $o == 127 )
            last OUTER if $o == 13;    #Enter
            if ( $c =~ /\d/ or $type == 0 ) {
                printf("$c");
                $string = $string . $c;
            }
        } ## end INNER: while ()
        $string = $c;
        last OUTER;
    } ## end OUTER: while ()
    ReadMode('normal');
    $self->at( -2, 0, " " );
    return if $string eq $escape;
    return $default if length($string) == 0;
    chomp $string;
    return $string;
} ## end sub prompt

sub acknowledge {
    my ( $self, $prompt ) = @_;
    my $result      = "ZZ";
    my $full_prompt = $self->color_it( $prompt . " - <B>Enter</B>" );
    ReadMode('cbreak');
    $self->at( -2, 0, $full_prompt );
    while ( $result ne chr(13) ) {
        $result = ReadKey(0);
        if ( $result eq $escape ) {
            ReadMode('normal');
            return 1;
        }
    } ## end while ( $result ne chr(13...))
    ReadMode('normal');
    return 0;
} ## end sub acknowledge

sub display {
    my $self   = shift;
    my $prompt = shift;
    $self->{term}->at( 0, 0 )->puts(" ")->dl();
    $self->at( -4, 0, $self->color_it( sprintf( $prompt, @_ ) ) );
} ## end sub display

sub menu {
    my ( $self, $prompt, $arr, $default ) = @_;
    my $result;
    my $chooser = Term::Choose->new();

    # Try using a menu
    $self->at( -2, 0, "" );
    $result = $chooser->choose( $arr, { prompt => 'Choose program or "q" for manual' } );
    return $result if defined $result;
    $result = $self->string( $prompt . " (ESC for default[$default])", $default );
    return $result if $result ne $escape;
    return $default;
} ## end sub menu

sub simple_menu {
    my ( $self, $prompt, $arr ) = @_;
    my $result = &pick( $arr, $prompt );
    return if ( $result eq "]quit[" );
    return $result;
} ## end sub simple_menu

sub string {
    my ( $self, $prompt, $default ) = @_;
    $default = "" unless defined $default;
    return $self->prompt( $prompt, 0, $default );
}

sub number {
    my ( $self, $prompt, $default ) = @_;
    $default = 1 unless defined $default;
    return $self->prompt( $prompt, 1, $default );
}

sub get_char {
    my ( $self, $prompt ) = @_;
    my $msg          = "";
    my $valid_option = "";
    foreach my $bits ( split( "&", $prompt ) ) {
        next if length($bits) == 0;
        $valid_option = $valid_option . substr( $bits, 0, 1 );
        $msg = $msg . colored( substr( $bits, 0, 1 ), "yellow underline" ) . substr( $bits, 1 );
    }
    my $result = 'ZZ';
    ReadMode('cbreak');
    $self->at( -2, 0, $msg );
    while ( index( $valid_option, $result ) == -1 ) {
        $result = ReadKey(0);
        last if $result eq $escape;
    }
    ReadMode('normal');
    return $result;
} ## end sub get_char
my $ctrlC_value = "#CtrlC-value#";

sub ctrl_c {
    $SIG{INT} = \&ctrl_c;
    Clipboard->copy($ctrlC_value);
}

sub get_timestamp {
    my ( $self, $prompt, $default_value ) = @_;
    my $value       = "";
    my $full_prompt = sprintf( "%s [%s]: (Clipboard or ctrl-c):", $prompt, $default_value );
    $self->at( -2, 0, $full_prompt );
    Clipboard->copy("0000000000");
    select()->flush();

    # $self->get_multi( $prompt, 2, $default_value );
    $SIG{INT} = \&ctrl_c;
    my $n = 0;
    until ( $value =~ /^\d\d:\d\d:\d\d\.\d\d\d$/ ) {
        sleep(1);
        $value = Clipboard->paste;
        $value = $default_value if $value eq $ctrlC_value;
    }
    chomp $value;

    # $scr->at( $rows - 2, 0 )->puts($prompt)->clreol()->reverse()
    #     ->puts($value)->normal()->clreol();
    $SIG{INT} = 'DEFAULT';
    return $value;
} ## end sub get_timestamp
1;
