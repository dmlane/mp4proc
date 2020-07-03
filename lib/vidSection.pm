use strict;

# use lib::abs -soft => qw(. lib);
# use vidGlobals;
package vidSection;
my @episode_sections;
my @file_sections;

sub new {
    my ( $class, $db ) = @_;
    my $self = { db => $db };
    bless $self, $class;
}

=head2  add_section
Define a new section on the currently loaded file, validating before returning with
what needs to be done.
=cut

sub add_section {
    my ( $self, $section_number, $file_sections, $all_sections ) = @_;
}

=head2  change_episode
Populate episode data.
=cut

sub change_episode {
    my ( $self, $program, $series, $episode ) = @_;
    @episode_sections = @{ $self->db->get_episode_sections( $program, $series, $episode ) };
}

=head2  change_file
Populate episode data.
=cut

sub change_file {
    my ( $self, $file ) = @_;
    @file_sections = @{ $self->db->get_sections_of_raw_file($file) };
}
1;

#=========================== POD ============================#

=head1 NAME

  sectionHandler - handles sections ensuring no overlaps etc.. 

=cut
