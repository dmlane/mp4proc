use strict;

package vidDB;

use File::Basename;
use lib dirname(__FILE__);
use DBI;
use File::Copy qw(copy);
use Try::Tiny;
use Const::Fast;
use vidData;

our %env_params = (
    TEST => {
        login_path => "testdb",
        database   => "test"
    },
    PROD => {
        login_path => "videos",
        database   => "videos"
    }
);
our $gEnvironment;

sub import {
    my ( $self, $env ) = @_;
    if ( defined $env ) {
        unless ( $env eq 'PROD'
            or $env eq 'TEST' )
        {
            printf "Invalid environment '$env' in 'use $self'\n";
            exit(1);
        }
        $gEnvironment = $env;
    }
    else {
        $gEnvironment = 'TEST';
    }
}

=head2 read_params
Fetch the parameters from a parameter file using mysql utility. In MariaDB,
this function no longer exists, so I created a dummy script 
which produces the same results.
=cut

sub read_params {

    my ($login_path) = @_;
    my %arr;
    my $cmd = $ENV{"HOME"} . "/dev/videos/my_print_defaults";
    my $params;
    my $msg;

    die "$cmd missing" unless -e $cmd;
    open( $params, "-|", $cmd . " -s ${login_path}" );
    while (<$params>) {
        chomp;
        m/^\w*--([^=]*)=\s*([^\s]*)\s*$/;
        $arr{$1} = $2;
    }
    close($params);
    $msg = sprintf( "Host '%s',Port '%s',User '%s',Password '%s'\n Something not defined",
        $arr{host}, $arr{port}, $arr{user}, $arr{password} );
    die $msg
        unless exists $arr{host}
        and exists $arr{port}
        and exists $arr{user}
        and exists $arr{password};
    return %arr;
}

sub new {
    my ($class) = @_;
    my $self = {
        database  => $env_params{$gEnvironment}->{database},
        connected => 0,
        dbh       => "",
        read_params( $env_params{$gEnvironment}->{login_path} )
    };
    if ( $gEnvironment eq "TEST" ) {
        warn "Using TEST database\n";
        sleep(2);
    }
    bless $self, $class;
}

sub connect {
    my $self = shift;
    return
        if $self->{connected} == 1;
    $self->{dbh} = DBI->connect(
        sprintf(
            "DBI:MariaDB:database=%s;host=%s;port=%s",
            $self->{database}, $self->{host}, $self->{port}
        ),
        $self->{user},
        $self->{password},
        { RaiseError => 1, AutoCommit => 0 }
    ) or die $DBI::errstr;
    $self->{connected} = 1;
}

sub disconnect {
    my $self = shift;
    return
        if $self->{connected} == 0;
    $self->{dbh}->commit();
    $self->{dbh}->disconnect();
    $self->{connected} = 0;
}

sub exec {
    my ( $self, $stmt ) = @_;
    my $results;
    my $conn = $self->{connected};    # Store state so that we know what to do later
    $self->connect() if $conn == 0;
    try {
        my $sth = $self->{dbh}->prepare($stmt);
        $sth->execute();
    }
    catch {
        die ">>>Error found executing\n---\n$stmt\n---\n";
    };
    $self->disconnect() if $conn == 0;
    return $results;
}

=head2 fetch
Fetch the results of the select provided into a hash array
=cut

sub fetch {
    my ( $self, $stmt ) = @_;
    my $results;
    my $conn = $self->{connected};    # Store state so that we know what to do later
    $self->connect() if $conn == 0;
    try {
        my $sth = $self->{dbh}->prepare($stmt);
        $sth->execute();
        $results = $sth->fetchall_arrayref( {} );
    }
    catch {
        die ">>>Error found executing\n---\n$stmt\n---\n";
    };
    $self->disconnect() if $conn == 0;
    return $results;
}

sub fetch_number {
    my ( $self, $stmt ) = @_;
    my $results = $self->fetch($stmt);
    return ( values( %{ $results->[0] } ) )[0];
}

sub fetch_row {
    my ( $self, $stmt ) = @_;
    my $results = $self->fetch($stmt);
    return %{$results}[0];
}

sub get_programs {
    my ($self) = @_;
    my $res = $self->fetch(qq(select name from program order by name));
    return $res;
}

sub fetch_new_files {
    my ($self) = @_;
    return $self->fetch(
        qq( 
        select a.name file,a.k1,a.k2,a.video_length,a.last_updated,a.status raw_status,
        count(b.section_number) section_count
        from  raw_file a
            left outer join section b on b.raw_file_id =a.id
            where a.status<2
            group by a.name,a.status
              order by k1,k2;
              )
    );
}

sub delete_file {
    my ( $self, $file_name ) = @_;
    $self->exec(qq(update raw_file set status=99 where name="$file_name"));
}

sub delete_section {
    my ( $self, $id ) = @_;
    $self->exec(qq(delete from section where id=$id ));
}

sub add_section {
    my ( $self, $force, $args ) = @_;
    $self->connect();

    # Check file exists in raw_file
    my $raw_id = $self->fetch_number(qq(select id from raw_file where name="$args->{file}"));
    die "Could not find '$args->{file}' in raw_file" unless $raw_id;

    # File exists so check if section exists
    my $section_id = $self->fetch_number(
        qq(select section_id from videos where program_name="$args->{program}" and
                series_number=$args->{series} and
                episode_number=$args->{episode} and
                section_number=$args->{section})
    );
    if ( $section_id and !$force ) {
        return (1);
    }

    # Delete existing section, as we're replacing it
    if ($section_id) {
        $self->exec(qq(delete from section where id=$section_id));
    }
    #
    $self->exec(qq(insert ignore into program (name) values ("$args->{program}" )));
    my $program_id = $self->fetch_number(qq(select id from program where name= "$args->{program}"));
    #
    $self->exec(
        qq(insert ignore into series (series_number,program_id)
                    values ($args->{series},$program_id))
    );
    my $series_id = $self->fetch_number(
        qq(select id from series where program_id=$program_id and
                                         series_number= $args->{series})
    );
    #
    $self->exec(
        qq(insert  ignore into episode(episode_number,series_id) values (
                    $args->{episode},$series_id))
    );
    my $episode_id = $self->fetch_number(
        qq(select id from episode where series_id=$series_id and
                                         episode_number= $args->{episode})
    );
    #
    $self->exec(
        qq(insert into section(section_number,episode_id,start_time,end_time,raw_file_id,status)
                    values ($args->{section}, $episode_id , "$args->{start_time}","$args->{end_time}", $raw_id,0) )
    );
    #
    $args->{section_id} = $self->fetch_number(
        qq(
            select id from section
            where section_number=$args->{section} and episode_id=$episode_id 
            and raw_file_id=$raw_id
        )
    );
    #
    $self->disconnect();
}

sub get_sections_of_raw_file {
    my ( $self, $file ) = @_;
    return $self->fetch(
        qq(select section_id,program_name,series_number,episode_number,section_number,k1,k2,
                time_to_sec(start_time) start_time,time_to_sec(end_time) end_time from videos where file_name="$file"              
            )
    );
}

sub get_series_episodes {
    my ( $self, $program_name, $series_number ) = @_;
    return $self->fetch(
        qq(select program_name ,series_number,episode_number,duration,outlier
            from episode_status
            where program_name="$program_name" and series_number=$series_number
            order by episode_number
            )
    );
}

sub get_series_episode_sections {
    my ( $self, $program_name, $series_number, $episode_number ) = @_;
    return $self->fetch(
        qq(
            select file_name,program_name,series_number,episode_number,section_number,
                start_time,end_time
                from videos
                where program_name='$program_name' and series_number=$series_number
                and episode_number=$episode_number
                order by section_number
             )
    );
}

sub get_max_episodes {
    my ( $self, $program_name, $series_number ) = @_;
    my $res = $self->fetch_number(
        qq(select max_episodes from series a where series_number=$series_number and
                program_id in (
                    select id from program where name='$program_name'))
    );
}

sub set_max_episodes {
    my ( $self, $program_name, $series_number, $max_episodes ) = @_;
    $self->connect();
    $self->exec(qq(insert ignore into program (name) values ("$program_name" )));
    my $program_id = $self->fetch_number(qq(select id from program where name= "$program_name"));
    #
    $self->exec(
        qq(insert ignore into series (series_number,program_id)
                    values ($series_number,$program_id))
    );
    my $series_id = $self->fetch_number(
        qq(select id from series where program_id=$program_id and
                                         series_number= $series_number)
    );
    $self->exec(
        qq(update series set max_episodes=$max_episodes
                where id=$series_id)
    );
    $self->disconnect();
}
1;
