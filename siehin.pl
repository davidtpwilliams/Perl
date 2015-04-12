e warnings;
use strict;

use Net::POP3;
use Net::SMTP;

my $subject_width = 50;
my $from_width    = 80;

my $mailserver = "pop.mycompany.com.au";
my $username   = "myusername";      # SIHELPDESK mailbox
my $password   = "mycompany162";
my $ithelpdesk = "support\@yourcompany.co.uk";
my $other1 = "davidw\@mycompany.com.au";    # The following other email addresses for testing only
my $other2 = "jefft\@mycompany.com.au";
my $other3 = "julieb\@mycompany.com.au";
my $msg;
my $msgList;
my $header;
my $smtp;
my $pop3;
my $tot_msg;
my $body;
my $datetime = scalar(localtime(time));
my $trackit;
my $subject;
my $from;

# Setup connecton to mail server and logging.
chomp ($mailserver, $username, $password);
$smtp    = Net::SMTP->new('smtp.mycompany.com.au') or die "Failed to connect to $mailserver";
$pop3    = Net::POP3->new($mailserver)       or die "Failed to connect to $mailserver";
$tot_msg = $pop3->login($username,$password) or die "Failed to authenticate $username";

open (LOGFILE, '>>/var/log/jira.log');
printf("\n   There are $tot_msg messages\n\n");   # Used for testing if run by hand.
exit if ("$tot_msg" == 0);

#print LOGFILE "$datetime\n";
#print LOGFILE "    There are $tot_msg messages\n";

# Process message Queue
$msgList = $pop3->list();
foreach $msg (keys(%$msgList))
  {
  $header = $pop3->top($msg, 0);
  $body = $pop3->get($msg);
  ($subject, $from) = analyze_header($header);
  print "$from\n";
  # Send messsage to next mail box if TrackIt
  $trackit = substr $subject, 0, 6;
  $trackit =~ s|\D||g;
  print "Trackit = $trackit\n";
  if ((index($from, $ithelpdesk ) != -1 || index($from, $other1 ) != -1 ) && AddNewIssue( $subject ) == 1 && DuplicateTrackit($trackit) == 0)
     {
     # Now remove any "Modified Work Order:" strings from the subject line
     my $find = "Modified: Work Order,";
     my $replace = "";
     @$body = map {$_ =~ s/$find/$replace/g; $_} @$body;
     print LOGFILE "$datetime - Adding the following issue into JIRA...\n";
     print LOGFILE "    From: $from [$subject]\n";;
     $smtp->mail("sihelpdesk\@mycompany.com.au");
     $smtp->to('sihelpdesk2@mycompany.com.au');
    $smtp->data();
     $smtp->datasend(@$body);
     $smtp->dataend();
     }
  $pop3->delete($msg); # not really deleted until quit is called
  }
$pop3 -> quit;  # deleted messages are deleted now
close(LOGFILE);

sub analyze_header
{
  my $header_array_ref = shift;
  my $header2 = join "", @$header_array_ref;
  my ($subject) = $header2 =~ /Subject: (.*)/m;
  my ($from   ) = $header2 =~ /From: (.*)/m;
  return ($subject, $from);
}

# Function to exclude emails base on text in the subject
sub AddNewIssue
{
my $string = shift;
my $substr = "Completed Work Order";
my $substr2 = "Expected Completion Date Warning";
my $substr3 = "Expected Completion Date  Overdue";
my $substr4 = "FW:";
my $substr5 = "RE:";
my $substr6 = "/ [0-9][0-9][0-9][0-9][0-9]";
my $substr7 = "/[0-9][0-9][0-9][0-9][0-9]";
my $substr8 = "Resolved";

#Ignore forwarded and reply emails
if ($string =~ m/^($substr4|$substr5)/)
   {
   return 0;
   }

#Look for a HelpDesk job number in the subject with format / 21879
if (($string =~ m/$substr6$/) || ($string =~ m/$substr7$/))
   {
   print LOGFILE "$datetime\n";
   print LOGFILE "    ###: I detect an SI job number; exiting\n";
   print LOGFILE "    $string\n";
   return 0
   }

#Ignore follow up trackIt emails; completed etc.
if ($string =~ m/($substr|$substr2|$substr3|$substr8)/)
   {
   return 0;
   }
return 1;
}

# Check for duplicate trackit, if yes do not add to file.
sub DuplicateTrackit
{
my $trackit = shift;
my $numlines = 200;
# Check file for existing trackit
my $result = `grep -x $trackit /var/log/trackit.log`;
print "result $result\n";
if ($result eq "" && length($trackit) > 4)
   {
   `tail -n$numlines /var/log/trackit.log > out1; mv out1 /var/log/trackit.log`;
   print "Adding $trackit\n";
   open (TRACKLOG, '>>/var/log/trackit.log');
   print TRACKLOG "$trackit\n";
   close(TRACKLOG);
   return 0;
   }
if (length($trackit) > 4)
   {
   print LOGFILE "$datetime\n";
   print LOGFILE "Duplicate Trackit found - $trackit\n";
   }
return 1;
}


