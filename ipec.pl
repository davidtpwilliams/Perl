#!/usr/bin/perl
use POSIX qw/strftime/;
use Net::FTP;
use File::Copy;
use strict;
use Switch;

my @Fields;
my $RawDataFile;
my $BINDIR="/data/caust/bin";
my $IPEC_DIR="/data/caust/IPEC";
my $UNIFY="/data/caust/unify";
my $EXCLUDE_RADIO_FREQ= "\'44\', \'51\', \'42\', \'AL\', \'BU\', \'DS\', \'ES\', \'GE\', \'KA\', \'47\', \'50\'";
my $Count = 0;

# !!! print "Ipec.pl is disabled.......\n";
# !!! exit(0);

# !!! Get a list of the job numbers from the last call to ipec.pl
# !!! This is not longer used to check exported job numbers
my @JobNumberList;
StorePreviousJobNumbers();

# !!! Create and run SQL 
CreateSQLScript();
RunSQLScript();

# !!! Read raw data from file created by SQL statement
$RawDataFile = "$BINDIR/ipec.data";
open(SERVERLIST, "< $RawDataFile")
    or exit(1);

while (<SERVERLIST>)
   {
    chomp;
    @Fields = split(/\|/, $_);
    # !!! Clean up the data, remove leading and trailing spaces and end of line;
    foreach (@Fields)
       {
       chomp;
       $_ =~ s/^\s+//;
       $_  =~ s/\s+$//;
       }
    PrintXMLToFile( );
    $Count++;
   }

close(SERVERLIST);

print "Number of .xml files created = $Count\n";
# !!! FTP files to TOLL and move to achive directory 
system("/usr/bin/perl $BINDIR/FTP.pl ");
exit(0);

################################################################################
#  subroutines implementation
################################################################################
# Subtract 5 minutes from the current time
sub  FormatTime
   {
   my $Period = 5;
   my $AdjustedTime;
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

   if ($min - $Period >= 0 )
      {
      my $adjustedMinute = $min - $Period;
      # Need to add a 0 to string if only 1 digit
      if ( $adjustedMinute < 10)
         {
         $AdjustedTime = "$hour:0$adjustedMinute";
         }
      else
         {
         $AdjustedTime = "$hour:$adjustedMinute";
         } 
      }
   else
      {
      my $adjustedMinute = 60 + ($min - $Period);
      print "$adjustedMinute \n";
      if ($hour > 0)
         {
         $hour = $hour -1;
         $AdjustedTime = "$hour:$adjustedMinute";
         }
      else
         {
         $hour = 23;
         $AdjustedTime = "$hour:$adjustedMinute";
         }
      }
   }

sub CreateSQLScript
   {
   # Get todays date and format the time to 5 in the past
   my $today = strftime('%d/%m/%Y',localtime);
   my $cutOffTime = FormatTime(); 
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   my $UptoTime;
   if ($min < 10)
      {
      $UptoTime = "$hour:0$min";
      }
   else
      {
      $UptoTime = "$hour:$min";
      }
   open (MYFILE, ">$BINDIR/ipec.sql"); 
   print MYFILE  "lines 0\n";
   print MYFILE  "select\n";
   print MYFILE  "\'sendPickupNotify',\n";
   print MYFILE  "\'Notification',\n";
   print MYFILE  "\'1',\n";
   print MYFILE  "pricedoc.status_date,\n";
   print MYFILE  "pricedoc.status_time,\n";
   print MYFILE  "\'IPEC',\n";
   print MYFILE  "\'Toll IPEC',\n";
   print MYFILE  "\'CC4300',\n";
   print MYFILE  "pricedoc.job_no,\n";
   print MYFILE  "pricedoc.booked_by,\n";
   print MYFILE  "customer.name,\n";
   print MYFILE  "\' \',\n";
   print MYFILE  "pricedoc.from_comment,\n";
   print MYFILE  "pricedoc.from_contact,\n";
   print MYFILE  "pricedoc.from_address_2,\n";
   print MYFILE  "pricedoc.from_address_1,\n";
   print MYFILE  "subname1.name,\n";
   print MYFILE  "subname1.booking_flg,\n";
   print MYFILE  "\'AU\',\n";
   print MYFILE  "pricedoc.booking_date,\n";
   print MYFILE  "pricedoc.booking_time,\n";
   print MYFILE  "\' \',\n";
   print MYFILE  "pricedoc.ready_time,\n";
   print MYFILE  "pricedoc.pickup_clos_time,\n";
   print MYFILE  "pricedoc.send_recv_flag,\n"; 
   print MYFILE  "\'N\',\n";
   print MYFILE  "\'N\',\n";
   print MYFILE  "\'Y\',\n";
   print MYFILE  "\' \',\n";
   print MYFILE  "pricedoc.numb_of_units_1,\n";
   print MYFILE  "subname1.code,\n";
   print MYFILE  "subname2.code,\n";
   print MYFILE  "pricedoc.numb_of_units_2,\n";
   print MYFILE  "pricedoc.numb_of_units_3,\n";
   print MYFILE  "pricedoc.numb_of_units_4,\n";
   print MYFILE  "pricedoc.numb_of_units_5,\n";
   print MYFILE  "pricedoc.service_code,\n";
   print MYFILE  "service.description,\n";
   print MYFILE  "pricedoc.to_address_2,\n";
   print MYFILE  "pricedoc.to_address_1,\n";
   print MYFILE  "subname2.name,\n";
   print MYFILE  "\' \',\n";
   print MYFILE  "subname2.booking_flg,\n";
   print MYFILE  "\'AU\'\n";
   print MYFILE  "from pricedoc, service, customer, subname  subname1, subname  subname2\n";
   print MYFILE  "where pricedoc.status_date = $today\n";
   print MYFILE  "and pricedoc.status_time >= $cutOffTime\n";
   print MYFILE  "and pricedoc.status_time < $UptoTime\n";
   print MYFILE  "and pricedoc.customer_key ^= \'W931098\'\n";
   print MYFILE  "and not pricedoc.radio_frequency in <$EXCLUDE_RADIO_FREQ>\n";
   print MYFILE  "and pricedoc.job_status in < \'U\',\'m\'>\n";
   print MYFILE  "and pricedoc.service_code = service.code\n";
   print MYFILE  "and pricedoc.customer_key = customer.cust_key\n";
   print MYFILE  "and pricedoc.to_suburb_code = subname2.code\n";
   print MYFILE  "and pricedoc.from_suburb_code = subname1.code\n";
   print MYFILE  "/\n";
   close(MYFILE);    
   }

sub RunSQLScript
   {
   my $command = "$UNIFY/bin/SQL $BINDIR/ipec.sql > $BINDIR/ipec.data";
   my $rval = system($command);
   }

sub PrintXMLToFile
   {
   # Add the job number to the file name
   my $state;
   my $xmlFile = ">$IPEC_DIR/ipec$Fields[8].xml";
   open (MYFILE, $xmlFile);
   my $ContactName = $Fields[13];
   my $ContactNumber = $Fields[13];
   $ContactName =~ s/[^A-Za-z]//g;
   if (!$ContactName)
      {
      $ContactName = $Fields[9];
      }
   $ContactNumber =~ s/\D//g;

   # !!! Check number and add default if empty
   if (length ($ContactNumber) <  8)
      {
      $ContactNumber = "0894580066";
      }

   print MYFILE "<?xml version=\"1.0\" ?>  \n";
   print MYFILE " <request> \n";
   print MYFILE " <header> \n";
   print MYFILE "  <action>$Fields[0]</action>  \n";
   print MYFILE "  <interface>$Fields[1]</interface>  \n";
   print MYFILE "  <interfaceVersion>$Fields[2]</interfaceVersion>  \n";
   print MYFILE "  </header> \n";
   print MYFILE " <data> \n";
   my $CreationDate = FormatDate($Fields[3]);
   print MYFILE "  <recordCreateDateTime>$CreationDate $Fields[4]:00:000</recordCreateDateTime>  \n";
   print MYFILE "  <businessId>$Fields[5]</businessId>  \n";
   print MYFILE "  <businessName>$Fields[6]</businessName>  \n";
   print MYFILE "  <accountCode>$Fields[7]</accountCode>  \n";
   print MYFILE "  <userId /> \n";
   print MYFILE "  <userName /> \n";
   print MYFILE "  <contactNumber /> \n";
   $Fields[9] =~s/\&/and/;
   print MYFILE "  <contactName>$Fields[9]</contactName>  \n";
   print MYFILE "  <emailAddress />  \n";
   print MYFILE "  <pickupContactNumber>$ContactNumber</pickupContactNumber>  \n";
   print MYFILE "  <pickupContactName>$ContactName</pickupContactName>  \n";
   $Fields[14] =~s/\&/and/;
   print MYFILE "  <companyName>$Fields[14]</companyName>  \n";
   $Fields[15] =~s/\&/and/;
   print MYFILE "  <address1>$Fields[15]</address1>  \n";
   print MYFILE "  <address2 />  \n";
   if (($Fields[30] eq "VARIO0") || ($Fields[30] eq "VARIO1"))
      {
      print "WHAT.......\n";
      $Fields[16] = "VARIOUS";
      $Fields[17] = "9999";
      }
   print MYFILE "  <suburb>$Fields[16]</suburb>  \n";
   $state = GetState($Fields[17]);
   print MYFILE "  <state>$state</state>  \n";
   print MYFILE "  <postCode>$Fields[17]</postCode>  \n";
   print MYFILE "  <country>$Fields[18]</country>  \n";
   my $PickupDate = FormatDate($Fields[19]);
   print MYFILE "  <pickupDateTimeDateObject>$PickupDate $Fields[20]:00.000</pickupDateTimeDateObject>  \n";
   print MYFILE "  <openTimeDateObject>$PickupDate $Fields[22]:00.000</openTimeDateObject>  \n";
   print MYFILE "  <closeTimeDateObject>$PickupDate $Fields[23]:00.000</closeTimeDateObject>  \n";
   #!! Check for third party and if so add to next section
   if ($Fields[24] eq "T")
      {
      print MYFILE "  <specialRequirements>CA Ref:$Fields[8]:$Fields[12]:THIRD PARTY:$Fields[10]</specialRequirements>\n";
      }
   else
      {
      print MYFILE "  <specialRequirements>CA Ref:$Fields[8]:$Fields[12]</specialRequirements>\n";
      }
   print MYFILE "  <bringConnote>$Fields[25]</bringConnote>  \n";
   print MYFILE "  <regularPickup>$Fields[26]</regularPickup>  \n";
   print MYFILE "  <sameLocation>$Fields[27]</sameLocation>  \n";
   print MYFILE "  <confirmationNumber>IPEC:$Fields[7]:$Fields[8]</confirmationNumber>  \n";
   print MYFILE " <items> \n";
   if ($Fields[29] == 0)
      {
      $Fields[29] = 1;
      }
   print MYFILE "  <numberOfItems>$Fields[29]</numberOfItems>  \n";
   print MYFILE "  <itemType /> \n";
   print MYFILE "  <itemTypeName /> \n";
   if ($Fields[32] == 0)
      {
      $Fields[32] = 1;
      }
   print MYFILE "  <weight>$Fields[32]</weight>  \n";
   print MYFILE "  <dimensionL>$Fields[33]</dimensionL>  \n";
   print MYFILE "  <dimensionW>$Fields[34]</dimensionW>  \n";
   print MYFILE "  <dimensionH>$Fields[35]</dimensionH>  \n";
   if ($Fields[36] eq "AF")
      {
      print MYFILE "  <serviceCode>A</serviceCode>  \n";
      print MYFILE "  <serviceName>PRIORITY</serviceName>  \n";
      }
   else
      {
      print MYFILE "  <serviceCode>R</serviceCode>  \n";
      print MYFILE "  <serviceName>ROAD</serviceName>  \n";
      }
   $Fields[38] =~s/\&/and/;
   print MYFILE "  <destinationCompanyName>$Fields[38]</destinationCompanyName>  \n";
   $Fields[39] =~s/\&/and/;
   print MYFILE "  <destinationAddress1>$Fields[39]</destinationAddress1>  \n";
   print MYFILE "  <destinationAddress2 />  \n";
   if ($Fields[31] eq "VARIO0" || $Fields[31] eq "VARIO1")
      {
      $Fields[40] = "VARIOUS";
      $Fields[42] = "9999";
      }
   print MYFILE "  <destinationSuburb>$Fields[40]</destinationSuburb>  \n";
   $state = GetState($Fields[42]);
   print MYFILE "  <destinationState>$state</destinationState>  \n";
   print MYFILE "  <destinationPostCode>$Fields[42]</destinationPostCode>  \n";
   print MYFILE "  <destinationCountry>$Fields[43]</destinationCountry>  \n";
   print MYFILE " </items> \n";
   print MYFILE " </data> \n";
   print MYFILE " </request>\n";
   close (MYFILE);
   }

# Format date from 15/05/10 to 2010-05-15
sub FormatDate
   {
   my @newDate;
   my $newYear;
   my $returnDate;   
   @newDate = split(/\//, $_[0]);
   $newYear = $newDate[2] + 2000;
   $returnDate = "$newYear-$newDate[1]-$newDate[0]";
   }

sub StorePreviousJobNumbers
   {
   # Open old data file and extract job numbers
   $RawDataFile = "$BINDIR/ipec.data";
   open(SERVERLIST, "< $RawDataFile")
      or return;

   while (<SERVERLIST>)
      {
      chomp;
      my @line = split( /\|/, $_);
      push(@JobNumberList, $line[8]);
      }  
   close(SERVERLIST);
   
   # Clean up the data for late comparison
   foreach (@JobNumberList)
      {
      chomp;
      $_ =~ s/^\s+//;
      $_  =~ s/\s+$//;
      }
   }

sub GetState
   {
   my $return;
   switch($_[0])
      {
      case 9999 { $return = "NSW"; }
      case [2000..2599, 2619..2898,2921..2999]   { $return = "NSW"; }
      case [2600..2618, 2900..2920]  { $return = "ACT" }
      case [3000..3999]  { $return = "VIC" }
      case [4000..4999]  { $return = "QLD" }
      case [5000..5999]  { $return = "SA" }
      case [6000..6999]  { $return = "WA" }
      case [7000..7999]  { $return = "TAS" }
      case [800..999]   { $return = "NT" }
      else { $return = "NA" }
      }
      $return;
   }
