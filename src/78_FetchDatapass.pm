#
# 78_FetchDatapass.pm
# The API 
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Module
use strict;
use warnings;
use Time::Local;
use POSIX qw( strftime );
use HttpUtils;
use JSON qw( decode_json );

my $MODUL = "FetchDatapass";

###############################################
# Help Function to have a standard logging
#
#
# begin FetchDatapass_Log
#
sub FetchDatapass_Log($$$)
{
   my ( $hash, $loglevel, $text ) = @_;
   my $xline       = ( caller(0) )[2];
   
   my $xsubroutine = ( caller(1) )[3];
   my $sub         = ( split( ':', $xsubroutine ) )[2];
   $sub =~ s/FetchDatapass_//;

   my $instName = ( ref($hash) eq "HASH" ) ? $hash->{NAME} : $hash;
   Log3 $hash, $loglevel, "$MODUL $instName: $sub.$xline " . $text;
}
#
# end FetchDatapass_Log
###############################################

###############################################
# begin FetchDatapass_Initialize
#
sub FetchDatapass_Initialize($) {

    my ($hash) = @_;
    my $TYPE = "FetchDatapass";

    $hash->{DefFn}    = $TYPE . "_Define";
    $hash->{UndefFn}  = $TYPE . "_Undefine";
    $hash->{SetFn}    = $TYPE . "_Set";
    $hash->{GetFn}    = $TYPE . "_Get";
    $hash->{NotifyFn} = $TYPE . "_Notify";

    $hash->{NOTIFYDEV} = "global";

    $hash->{DbLog_splitFn}= $TYPE . "_DbLog_splitFn";
#    $hash->{AttrFn}       = $TYPE . "_Attr";


 $hash->{AttrList} = ""
    . "disable:1,0 "
    . "interval "
    . "interval_night "
    . $readingFnAttributes
  ;
}
#
# end FetchDatapass_Initialize
###############################################

###############################################
# begin FetchDatapass_Define
#
sub FetchDatapass_Define($$) {

    my ($hash, $def) = @_;
    my @args = split("[ \t][ \t]*", $def);

    return "Usage: define <name> FetchDatapass" if(@args <1 || @args >2);

    my $name = $args[0];
    my $type = "FetchDatapass";
    my $interval = 60;

    $hash->{NAME} = $name;

    $hash->{STATE}    = "Initializing" if $interval > 0;
    $hash->{helper}{INTERVAL} = $interval;
    $hash->{MODEL}    = $type;
    
  #Clear Everything, remove all timers for this module
  RemoveInternalTimer($hash);
  
  # Starting the timer to get data from www.datapass.de.
  
  # InternalTimer(gettimeofday() + 10, "FetchDatapass_GetData", $hash, 0);

  $hash->{fhem}{modulVersion} = '$V0.0.1$';
 
  return undef;
}
#
# end FetchDatapass_Define
###############################################
