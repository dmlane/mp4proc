use strict;

package modDB;
use lib::abs -soft => qw(. lib);

# use File::Basename;
# use lib dirname(__FILE__);
use DBI;

#use File::Copy qw(copy);
use Try::Tiny;

#use Const::Fast;
use Moo;
with 'MooX::Singleton';
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

# Class variables
has conf        => ( is => 'rw' );
has connected   => ( is => 'rw', default => 0 );
has dbh         => ( is => 'rw', default => "" );
has level       => ( is => 'rw', default => 'TEST' );
has catch_error => ( is => 'rw', default => 1 );

=head2 read_params
Fetch the parameters from a parameter file using mysql utility. In MariaDB,
this function no longer exists, so I created a dummy script 
which produces the same results.
=cut

sub read_params {

    my ($login_path) = @_;
    my %arr;
    my $cmd = $ENV{"HOME"} . "/dev/mp4proc/my_print_defaults";
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
} ## end sub read_params

sub BUILD {
    my ($self) = @_;
    my $conf = {
        database => $env_params{ $self->level }->{database},
        read_params( $env_params{ $self->level }->{login_path} )
    };
    if ( $self->level eq "TEST" ) {
        warn "Using TEST database\n";
        sleep(2);
    }
    $self->conf($conf);
} ## end sub BUILD

sub connect {
    my $self = shift;
    return
        if $self->connected == 1;
    $self->dbh(
        DBI->connect(
            sprintf(
                "DBI:MariaDB:database=%s;host=%s;port=%s",
                $self->conf->{database},
                $self->conf->{host},
                $self->conf->{port}
            ),
            $self->conf->{user},
            $self->conf->{password},
            { RaiseError => 1, AutoCommit => 0 }
            )
            or die $DBI::errstr
    );
    $self->connected(1);
} ## end sub connect

sub disconnect {
    my ( $self, $action ) = @_;
    return
        if $self->connected == 0;
    $action = 0 unless defined $action;
    if ( $action == 0 ) {
        $self->dbh->commit();
    }
    else {
        $self->dbh->rollback();
    }
    $self->dbh->disconnect();
    $self->connected(0);
} ## end sub disconnect

sub exec {
    my ( $self, $stmt ) = @_;
    my $results;
    my $conn = $self->connected;    # Store state so that we know what to do later
    $self->connect() if $conn == 0;
    try {
        my $sth = $self->dbh->prepare($stmt);
        $sth->execute();
    }
    catch {
        die ">>>Error found executing\n---\n$stmt\n---\n";
    };
    $self->disconnect() if $conn == 0;
    return $results;
} ## end sub exec

sub ignore_error {
    my ($self) = @_;
    $self->catch_error(0);
}

=head2 fetch
Fetch the results of the select provided into a hash array
=cut

sub fetch {
    my ( $self, $stmt ) = @_;
    my $results;
    my $conn = $self->connected;    # Store state so that we know what to do later
    $self->connect() if $conn == 0;
    try {
        my $sth = $self->dbh->prepare($stmt);
        $sth->execute();
        $results = $sth->fetchall_arrayref( {} );
    }
    catch {
        die ">>>Error found executing\n---\n$stmt\n---\n"
            unless $self->{catch_error} eq 0;
        $self->catch_error(1);
    };
    $self->disconnect() if $conn == 0;
    return $results;
} ## end sub fetch

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
1;
