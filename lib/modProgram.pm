use strict;

package modProgram;
my $testOrProd = "PROD";
use lib::abs -soft => qw(. lib);
use Moo;
with 'MooX::Singleton';
use Module::Load; 
use modData;

# use feature qw(refaliasing);
# no warnings qw(experimental::refaliasing);
# Pointer to classes
 
# Class variables
has dirty        => ( is => 'rw', default => 1 );
has program_list => ( is => 'rw' );

sub fetch_programs {
    my ( $self, $file_name ) = @_;
    my @arr;
    my $result = $db->fetch(qq(select name from program order by name asc));
    for ( my $n = 0; $n < @{$result}; $n++ ) {
        $arr[$n] = $result->[$n]->{name};
    }
    $self->program_list( \@arr );
    $self->dirty(0);
} ## end sub fetch_programs

sub set {
    my ( $self, $new_val ) = @_;
    $self->fetch_programs() if $self->{dirty} == 1;
    unless ( defined $new_val ) {
        $new_val = $scr->menu( "Which program name", $self->{program_list}, "" );
        return 1 if length($new_val) == 0;
    }

    # Same as last time?
    return (0) if $new_val eq $program;
    unless ( grep { $_ eq $new_val } @{ $self->program_list } ) {

        # Program is a new one
        $db->exec(qq(insert ignore into program (name) values ("$new_val")));
        $self->dirty(1);    # Mark list of programs as invalid
    } ## end unless ( grep { $_ eq $new_val...})

    # Get primary key
    $program_id = $db->fetch_number(qq(select id from program where name='$new_val'));
    $program    = $new_val;
    $series=-1;
    $episode=-1;
    $section=-1;

    return;
} ## end sub set

sub BUILD {
    my $self = shift;
    }
1;
