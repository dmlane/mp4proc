#!/usr/bin/env perl
use strict;
use Sys::Hostname;
use Log::Log4perl qw(get_logger);
use lib::abs -soft => qw(. lib);
use modDB;
use Cwd 'abs_path';
use modFileHandler;

# Screen
use modScreen;
my $testOrProd = "PROD";
use experimental qw(switch );
my $db               = modDB->instance( level => "$testOrProd" );
my $host             = hostname;
my $scriptdir        = abs_path($0);
my $script_err_count = 0;

$scriptdir =~ s/\/[^\/]*$//;

#---------------------------------------------------------------------------------
my ($fn) = @ARGV;


 my $d = $db->fetch_number(
    qq(
    select count(*) from raw_file R 
        where R.name='$fn'
        and exists (select 'x' from section S 
                    where R.id=S.raw_file_id 
                    and   S.status=0)
                    )
);

 exit($d);
