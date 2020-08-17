#!/usr/bin/env perl
use strict;
use lib::abs -soft => qw(. lib);
use modScreen;
    
# $db       = modDB->instance( level => "$testOrProd" );
my $scr      = modScreen->instance();
my @programs = ( "Alias", "Lost Whatever" );
my $res;
my @arr;
my $s=0;
my ($n,$m);

foreach $n (  ('A','B','C')){
    foreach   $m (  ('a','b','c')){
        $arr[$s++]=$n.$m;

    } 
}

# while ( $res ne "End" ) {
#     $res = $scr->menu( "Give me something", \@programs, "Alias" );
# }

$res=$scr->menu ("heelo",\@arr,"abc");

# $res = $scr->string( "Give me a string", "ABC" );
$res = $scr->number( "Give me a number", "301156" );

for(my $n=0;$n<100;$n++){
    $scr->display("Line number $n");
    sleep(1);
}


printf "\n\n>>$res<<\n";
print "End of run\n";
