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
    $hash->{URL} = "http://datapass.de/";
    $hash->{STATE}    = "Initializing" if $interval > 0;
    $hash->{helper}{INTERVAL} = $interval;
    $hash->{MODEL}    = $type;
    
  #Clear Everything, remove all timers for this module
  RemoveInternalTimer($hash);
  
  # Starting the timer to get data from www.datapass.de.
  
  InternalTimer(gettimeofday() + 10, "FetchDatapass_GetData", $hash, 0);

  $hash->{fhem}{modulVersion} = '$V0.0.1$';
 
  return undef;
}
#
# end FetchDatapass_Define
###############################################

###############################################
# begin FetchDatapass_GetData
#
sub FetchDatapass_GetData($) {

	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $interval = FetchDatapass_getInterval($hash);

	FetchDatapass_Log($hash, 5, "$name: Getting data from base url from $hash->{URL}");

	FetchDatapass_PerformHttpRequest($hash, $hash->{URL}, "DATA");

	# Now add a next timer for getting the data
	InternalTimer(gettimeofday() + $interval, "FetchDatapass_GetData", $hash, 0);
}
#
# end FetchDatapass_GetData
###############################################


###############################################
# begin FetchDatapass_PerformHttpRequest
#
#
# Perform the http request as a non-blocking request
#
sub FetchDatapass_PerformHttpRequest($$)
{
    my ($hash, $url, $callname) = @_;
    my $name = $hash->{NAME};

    $hash->{STATE}    = "Receiving data";

    my $param = {
                    url        => $url,
                    timeout    => 5,
                    hash       => $hash,                                                                                 # Muss gesetzt werden, damit die Callback funktion wieder $hash hat
                    method     => "GET",                                                                                 # Lesen von Inhalten
                    header     => "User-Agent: Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36\r\nAccept: text/html",                            # Den Header gemäß abzufragender Daten ändern
                    callback   => \&FetchDatapass_ParseHttpResponse,                                                    # Diese Funktion soll das Ergebnis dieser HTTP Anfrage bearbeiten
                    call       => $callname
                };

    FetchDatapass_Log($hash, 5, "$name: Executing non-blocking get for $url");

    HttpUtils_NonblockingGet($param);                                                                                    # Starten der HTTP Abfrage. Es gibt keinen Return-Code. 
}
#
# end FetchDatapass_PerformHttpRequest
###############################################

###############################################
# begin FetchDatapass_ParseHttpResponse
#
sub FetchDatapass_ParseHttpResponse($)
{
    my ($param, $err, $data) = @_;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};
    my $interval = FetchDatapass_getInterval($hash);
    
    $hash->{STATE}    = "Data received";

    if($err ne "")                                                                                                      # wenn ein Fehler bei der HTTP Abfrage aufgetreten ist
    {
	$hash->{STATE}    = "Connection error";
        FetchDatapass_Log($hash, 1, "error while requesting ".$param->{url}." - $err");                                            # Eintrag fürs Log
	if ($param->{call} eq "DATA") {
	  #
	  # if DATA Call failed, try again in 60 seconds
	  #
	  # InternalTimer(gettimeofday() + 60, "FetchDatapass_GetData", $hash, 0);
	  $hash->{STATE}    = "Connection error getting data";
	  FetchDatapass_Log($hash, 1, "DATA call to www.datapass.de failed");                                                         # Eintrag fürs Log
	} else {
	  FetchDatapass_Log($hash, 1, "Call to www.datapass.de failed for ".$param->{call}. "(".$param->{url}.")");                                                         # Eintrag fürs Log
	}
    }
    elsif($data ne "")                                                                                                  # wenn die Abfrage erfolgreich war ($data enthält die Ergebnisdaten des HTTP Aufrufes)
    {
        FetchDatapass_Log($hash, 5, "url ".$param->{url}." returned: $data");                                                         # Eintrag fürs Log

	if ($param->{call} eq "DATA") {
		#
		# This is the standard data call
		# 
		#FetchDatapass_GetData_Parse($hash, $data, $param->{call});
		my ($decimal, $fraction, $unita, $total, $totalunit) = $data =~ m/<div class="barTextBelow.*"><span class="colored">(\d*),?(\d*).*([a-zA-Z]{2})<\/span> von (\d*).*([a-zA-Z]{2}) verbraucht<\/div>/;
		FetchDatapass_Log($hash, 5, "Ergebnis: ".$decimal.",".$fraction.$unita."/".$total.$totalunit);
	} else {
		FetchDatapass_Log($hash, 1, "Error. Unknown call for ".$param->{call}); 
	}
    }
    
    # Damit ist die Abfrage zuende.
    # Evtl. einen InternalTimer neu schedulen
}
#
# end FetchDatapass_ParseHttpResponse
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

#
# Helper Functions
#
###############################################
# begin FetchDatapass_getInterval
#
#
# Helper function to the a valid interval value for data requests
#
sub FetchDatapass_getInterval($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $is_day = isday();

	my $interval = $attr{$name}{interval};
	# if there is no interval given, use the internal default
	if ($interval eq "") {
		# use default interval if none is given
		$interval = $hash->{helper}{INTERVAL};
	}
	
	# check if sun has gone. If yes and a night interval is set, use the night interval
	if ($is_day eq "0") {
		my $interval_night = $attr{$name}{interval_night};
		if ($interval_night ne "") {
			$interval = $interval_night;				
		}
	}

	# if interval is less then 5, we will use ten seconds as minimum
	if ($interval < 5) {
		# the minimum value
		$interval = 10;
		$attr{$name}{interval} = 10;
	}
	
	$hash->{helper}{last_used_interval} = $interval;
	$hash->{helper}{last_is_day} = $is_day;
	
	return $interval;
}
#
# end FetchDatapass_getInterval
###############################################


# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;
