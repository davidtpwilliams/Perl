#!/usr/bin/perl
use POSIX qw/strftime/;
use Net::FTP;
use Switch;

my @Fields;
my $BINDIR="/data/caust/bin";
my $UNIFY="/data/caust/unify";

# !!! Create and run SQL 
CreateSQLScript();
RunSQLScript();

exit;

################################################################################
#  subroutines implementation
################################################################################

sub CreateSQLScript
   {
   # Get todays date and format the time to 5 in the past
   my $today = strftime('%d/%m/%Y',localtime);
   my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   open (MYFILE, ">$BINDIR/ipecupd.sql"); 
   print MYFILE  "update pricedoc\n";
   print MYFILE  "set delivery_status =\'D\',\n";
   print MYFILE  "where pricedoc.status_date = $today\n";
   print MYFILE  "and pricedoc.driver_key ^= \'C555\'\n";
   print MYFILE  "and not pricedoc.delivery_status in <\'P\',\'D\'>\n";
   print MYFILE  "/\n";

   print MYFILE "update drivpd\n";
   print MYFILE "set undel_driv_key =\'DEL\'\n";
   print MYFILE "where driver_no =\'C555\'\n";
   print MYFILE "and not undel_driv_key in <\'DEL\',\'CON\'>\n";
   print MYFILE "and booking_date = $today\n";
   print MYFILE  "/\n";
   close(MYFILE);    
   }

sub RunSQLScript
   {
   my $command = "$UNIFY/bin/SQL $BINDIR/ipecupd.sql > $BINDIR/ipecupd.data";
   my $rval = system($command);
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

