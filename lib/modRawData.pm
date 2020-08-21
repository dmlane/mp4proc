use strict;

package modRawData;

use lib::abs -soft => qw(. lib);
use modDB;
use modFileHandler;
use modData;
use Moo;

with 'MooX::Singleton';

# Pointer to section handler
has section_handler => ( is => 'rw' );

# array containing all file details
has file => ( is => 'rw', default => sub { [] } );

# Database handle
has db => ( is => 'rw' );

# Index to file being processed
has ptr => ( is => 'rw', default => -1 );

# Highest index in use (points to high_values record)
has max_ptr => ( is => 'rw', default => 0 );
#
# Name of the current file pointed to by ptr
has name => ( is => 'rw', default => "" );

# Primary key value of the current file pointed to by ptr
has id => ( is => 'rw', default => 0 );

# Status of the current file pointed to by ptr
has status => ( is => 'rw', default => 0 );

# Number of sections of the current file pointed to by ptr
has num_sections => ( is => 'rw', default => 0 );

# Value used to indicate last record
my $high_values = 'ZZZZZZZZZZZ';

sub delete {
    my ($self) = @_;
    $self->db->exec(qq(delete from raw_file where name= '$self->{name}'));
    splice( @{ $self->{file} }, $self->{ptr}, 1 );
    $self->max_ptr( $self->{max_ptr} - 1 );
    my $n = $self->{ptr};
    $self->ptr( $self->{ptr} + 1 );
    $self->set($n);
} ## end sub delete

=head2 insert
Create a single raw_file record
=cut

sub insert {
    my ( $self, $fn, $video_length ) = @_;
    my $k1;
    my $k2;

    # Database can't do a version sort, so split the key fields so it can
    if ( $fn =~ m/^([^_]*_[^_]*_[^_]*)\./ ) {
        $k1 = $1;
        $k2 = 0;
    }
    else {
        ( $k1, $k2 ) = ( $fn =~ /^(.*)_(\d+)\..*$/ );
    }
    $self->db->exec(
        qq(
            insert into raw_file (name,k1,k2,video_length,status,last_updated)
            values('$fn','$k1',$k2,'$video_length',0,current_timestamp()))
    );
} ## end sub insert

=head2 add_new
Add all new files to the raw_file table
=cut

sub add_new {

    my ($self)    = @_;
    my $dbsub     = 0;
    my $new_count = 0;
    my $fh        = modFileHandler->instance();
    my $video_length;

    for ( my $fn = $fh->first(); $fn ne ""; $fn = $fh->next() ) {

        #printf("____________\n%s\n",$fn);
        # Skip until we catch up with $fn
        while ( $self->file->[$dbsub]->{file} lt $fn ) {

            #printf("%s\n",$self->file->[$dbsub]->{file});
            $dbsub++;
        }
        if ( $self->file->[$dbsub]->{file} eq $fn ) {
            $dbsub++;
            next;
        }

        # New file - insert it into database
        $video_length = $fh->video_length();
        if ( $video_length eq '00:00:00.000' ) {
            $scr->display("$fn has zero length - removing: ");
            $fh->remove_file();
        }
        else {
            $scr->display("Adding file $fn to videos.raw_file\n");
            $self->insert( $fn, $video_length );
            $new_count++;
        }
    } ## end for ( my $fn = $fh->first...)
    return $new_count;
} ## end sub add_new

=head2 fetch
Fetch all records with status <2 into $self->file and set $self->ptr to the first record  (0). 
A record with high-values is added to the end of the array to make processing easier.
=cut

sub fetch {
    my ($self) = @_;
    $scr->display("Fetching raw_files from database ........");
    my $raw_files = $self->db->fetch(
        qq( 
        select a.name file,a.k1,a.k2,a.video_length,a.last_updated,a.status raw_status,
        count(b.section_number) section_count,a.id raw_file_id
        from  raw_file a
            left outer join section b on b.raw_file_id =a.id
            where a.status<2
            group by a.name,a.status
              order by k1,k2;

        )
    );
    my $max_ptr = @{$raw_files};
    printf( " %d files loaded", $max_ptr );
    $raw_files->[$max_ptr] = { file => $high_values };
    my $lfn = "#";
    my $fn;
    my $remaining;

    for ( my $n = @{$raw_files} - 1; $n >= 0; $n-- ) {
        $fn = substr( $raw_files->[$n]->{name}, 0, 21 );
        if ( $fn ne $lfn ) {
            $lfn       = $fn;
            $remaining = -1;
        }
        $remaining++;
        $raw_files->[$n]->{remaining} = $remaining;
    } ## end for ( my $n = @{$raw_files...})
    $self->file($raw_files);
    $self->set(0) unless $max_ptr == 0;
    $self->max_ptr($max_ptr);
} ## end sub fetch

=head2 skip_over_files_with_sections
Sets the ptr to the first file which doesn't have sections
=cut

sub skip_over_files_with_sections {
    my ($self) = @_;
    my $n;
    for ( $n = 0; $n < @{ $self->file }; $n++ ) {
        last if $self->file->[$n]->{section_count} == 0;
    }
    $self->set($n);
    return ( $self->file->[$n] );
} ## end sub skip_over_files_with_sections

sub refresh {
    my $self = shift;
    $self->section_handler->fetch_raw_sections( $self->{id} );
}

=head2 prev
Move the pointer back 1
=cut

sub set {
    my ( $self, $new_value ) = @_;
    return 0 if $new_value == $self->{ptr};

    # Don't allow going beyond boundaries
    $oFileHandler->link_file( $self->{name}, 0 ) if defined $self->{name};
    $new_value = 0 if $self->{ptr} < 0;
    $new_value = $self->{max_ptr} if $self->{ptr} > $self->{max_ptr};
    $self->ptr($new_value);
    $self->id( $self->file->[$new_value]->{raw_file_id} );
    $files_remaining = $self->file->[$new_value]->{remaining};
    $self->name( $self->file->[$new_value]->{file} );
    $self->status( $self->file->[$new_value]->{raw_status} );
    $self->num_sections( $self->file->[$new_value]->{section_count} );
    $raw_id       = $self->id;
    $video_length = $self->file->[$new_value]->{video_length};
    $oSection->fetch_raw_sections();
    $oSection->print_sections();
    $oFileHandler->link_file( $self->{name}, 1 );
} ## end sub set

sub prev {
    my $self = shift;
    $self->set( $self->{ptr} - 1 );
}

sub next {
    my $self = shift;

    # $self->db->exec(
    #     qq(update raw_file set status=2 where id=$raw_id)
    # );
    $self->set( $self->{ptr} + 1 );
} ## end sub next

=head2 BUILD
Constructor for class
=cut

sub BUILD {
    my ($self) = @_;
    $self->db( modDB->instance() );
    $self->fetch();
}
1;
