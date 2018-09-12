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

###############################################
# begin FetchDatapass_Set
#
sub FetchDatapass_Set($$@) {
}
#
# end FetchDatapass_Set
###############################################


###############################################
# begin FetchDatapass_Get
#
sub FetchDatapass_Get($@) {
}
#
# end FetchDatapass_Get
###############################################

###############################################
# begin FetchDatapass_Undefine
#
sub FetchDatapass_Undefine($$) {
  my ($hash, $args) = @_;

  RemoveInternalTimer($hash);

  BlockingKill($hash->{helper}{RUNNING_PID}) if(defined($hash->{helper}{RUNNING_PID}));

  return undef;
} 
#
# end FetchDatapass_Undefine
###############################################


###############################################
# begin FetchDatapass_Notify
#
sub FetchDatapass_Notify($$)
{
	my ($own_hash, $dev_hash) = @_;
	my $ownName = $own_hash->{NAME}; # own name / hash

	FetchDatapass_Log $own_hash, 5, "Getting notify $ownName / $dev_hash->{NAME}";
 
	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
 
	my $devName = $dev_hash->{NAME}; # Device that created the events
	my $events = deviceEvents($dev_hash, 1);

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
	{
		 FetchDatapass_InitAttr($own_hash);
	}
}
#
# end FetchDatapass_Notify
###############################################

###############################################
# begin FetchDatapass_InitAttr
#
sub FetchDatapass_InitAttr($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};

	FetchDatapass_Log $hash, 1, "Initialising user setting (attr) for $name";
	
	if ($init_done) {

		FetchDatapass_Log $hash, 5, "User setting (attr) initialised for $name";
	} else {
		FetchDatapass_Log $hash, 1, "Fhem not ready yet, retry in 5 seconds";
	  	InternalTimer(gettimeofday() + 5, "FetchDatapass_InitAttr", $hash, 0);
	}
}
#
# end FetchDatapass_InitAttr
###############################################


# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;
