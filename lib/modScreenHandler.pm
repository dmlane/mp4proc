use strict;

package modScreenHandler;

use Term::Menus;
use Term::ReadKey;
use Term::ANSIColor qw(colored :constants);
use Clipboard;
use lib::abs -soft => qw(. lib);
use modDB;
use Term::Menus;
use Term::ReadKey;
use Term::ANSIColor qw(colored :constants);
use Const::Fast;
use Moo;

with 'MooX::Singleton';
has mp4_dir      => ( is => "rw" );
const my $escape => chr(27);

sub BUILD {
    my ($self) = @_;
    $| = 1;    #  # Auto-flush output (don't wait for \n)
}

sub top_menu {
    my ($self) = @_;
}

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

sub prompt {
    my ( $self, $prompt, $type, $default ) = @_;
    my $string = "";
    my $fmt    = "%s: ";
    $fmt = "%s [Default '<B>$default</B>']: " if ( length($default) > 0 );
    my $c;
    printf("\r%80s\r"," ");
    printf( $self->color_it( sprintf( $fmt, $prompt ) ) );
    my $o;
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
            last OUTER if $o == 10;    #Enter
            if ( $c =~ /\d/ or $type == 0 ) {
                printf("$c");
                $string = $string . $c;
            }
        } ## end INNER: while ()
        $string = $c;
        last OUTER;
    } ## end OUTER: while ()
    ReadMode('normal');
    printf( "\r%s\r", " " x 80 );
    return if $string eq $escape;
    return $default if length($string) == 0;
    chomp $string;
    return $string;
} ## end sub prompt

sub acknowledge {
    my ( $self, $prompt ) = @_;
    my $result      = "ZZ";
    my $full_prompt = $self->color_it( $prompt . " - <B>A</B>cknowledge" );
    ReadMode('cbreak');
    printf "\n$full_prompt\n";
    while ( index( "A", $result ) == -1 ) {
        $result = ReadKey(0);
        return 1 if $result eq $escape;
    }
    ReadMode('normal');
    return 0;
} ## end sub acknowledge

sub display {
    my ( $self, $prompt ) = @_;
    printf( $self->color_it($prompt) );
}

sub menu {
    my ( $self, $prompt, $arr, $default ) = @_;
    my $result;
    {
        # Try using a menu
        my $new = my @menu;
        $menu[0] = "*New*";
        push @menu, @$arr;
        $result = &pick( \@menu, $prompt );
        return $default if ( $result eq "]quit[" );
        return $result unless ( $result eq $menu[0] );
    }

    # Fall through to command line prompt
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

sub millisecs {
    my $ts = shift;
    $ts =~ /(..):(..):(..\....)/;
    return ( ( $1 * 60 + $2 ) * 60 + $3 );
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
    printf( "\r%s", $msg );
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
    printf("\r$full_prompt");
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
