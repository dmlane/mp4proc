use strict;

package modFileHandler;

use lib::abs -soft => qw(. lib);
use modDB;
use modData;
use Carp;
use File::Basename;
use MP4::Info;
use Moo;

with 'MooX::Singleton';
has mp4_dir => ( is => "rw" );
has pdir    => ( is => "rw" );
has file    => ( is => "rw", default => sub { [] } );
has ptr     => ( is => "rw" );

sub BUILD {
    my ($self) = @_;
    our %mp4_base_dir_options = (
        darwin  => "/System/Volumes/Data",
        linux   => "/Diskstation",
        MSWin32 => "Z:\\Videos\\Import"
    );
    my $os = $^O;
    croak "Unknown environment $os" unless ( defined $mp4_base_dir_options{$os} );
    $self->mp4_dir( $mp4_base_dir_options{$os} . "/Unix/Videos/Import" );
    $self->pdir( $mp4_base_dir_options{$os} . "/Unix/Videos/Import/processing" );
} ## end sub BUILD

sub video_length {
    my ($self) = @_;

    # Get the video length from the mp4 metadata
    my $info = get_mp4info( $self->file->[ $self->ptr ] );
    return "00:00:00.000" unless defined $info;
    my $video_length = sprintf(
        "%02d:%02d:%02d.%003d",
        int( $info->{MM} / 60 ),
        int( $info->{MM} % 60 ),
        $info->{SS}, $info->{MS}
    );
    return $video_length;
} ## end sub video_length

sub expand {
    my ( $self, $file ) = @_;
    my $fn = basename($file);
    my ( $k1, $k2 );
    if ( $fn =~ m/^([^_]*_[^_]*_[^_]*)\./ ) {
        $k1 = $1;
        $k2 = 0;
    }
    else {
        ( $k1, $k2 ) = ( $fn =~ /^(.*)_(\d+)\..*$/ );
    }

    # Used to sort files in version order
    $fn = sprintf( "%s_%3.3d", $k1, $k2 );
    return $fn;
} ## end sub expand

sub fetch {
    my ($self) = @_;
    my $dir = $self->mp4_dir;
    $scr->display( "Fetching unix_files from %s ........", $self->mp4_dir );
    my @mp4_files = sort { $self->expand($a) cmp $self->expand($b) } <$dir/V*.mp4>;

    # glob( $self->mp4_dir . '/*.mp4' );
    if ( @mp4_files == 0 ) {
        unless ( -d $self->mp4_dir ) {
            printf( "Can't find %s\n", $self->mp4_dir );
            die "Check network";
        }
    } ## end if ( @mp4_files == 0 )
    printf( " %d files loaded", scalar @mp4_files );
    $self->file( \@mp4_files );
} ## end sub fetch

sub first {
    my ($self) = @_;
    $self->ptr(-1);
    return $self->next();
}

sub next {
    my ($self) = @_;
    $self->ptr( $self->ptr + 1 );
    if ( defined $self->file->[ $self->ptr ] ) {
        return basename( $self->file->[ $self->ptr ] );
    }
    else {
        return "";
    }
} ## end sub next

sub remove_file {
    my ($self) = @_;
    my $fn = $oRawData->file->[ $oRawData->{ptr} ]->{file};
    my $mp4_name  = sprintf( "%s/%s", $self->{mp4_dir}, $fn );
    rename $mp4_name, $mp4_name . ".remove" or die "Failed to 'delete' $mp4_name";
    $self->link_file($fn,0);
    printf " deleted\n";
} ## end sub remove_file

sub link_file {
    my ( $self, $filename, $link ) = @_;
    my $link_name = sprintf( "%s/%s", $self->{pdir},    $filename );
    my $mp4_name  = sprintf( "%s/%s", $self->{mp4_dir}, $filename );
    unlink $link_name if -e $link_name;
    if ( $link == 1 ) {
        system("ln $mp4_name $link_name") == 0
            or die "Cannot ln $mp4_name to $link_name";
    }
} ## end sub process_file
1;
