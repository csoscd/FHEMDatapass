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
