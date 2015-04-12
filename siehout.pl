#!/usr/bin/perl
use strict;
use Net::POP3;

my $mailserver = "pop.mycompany.com.au";
my $username   = "myusername";
my $password   = "mycompany162";
my $ithelpdesk = "support\@yourcompany.co.uk";
my $msg;
my $msgList;
my $header;
my $pop3;
my $tot_msg;
my $body;
my $recipient1 = "davidw\@mycompany.com.au";
my $recipient2= "jefft\@mycompany.com.au";
my $recipient3= "julieb\@mycompany.com.au";
my $recipient4= "support\@yourcompany.co.uk";
my $recipient6 = "blakey247\@me.com";
my $recipient7 = "blakey247\@gmail.com";
my $tosubject;
my $substr = ")";
my $trackit;
my $jiratag;
my $status;
my $elem;
my $PagerCall;
my $OutOfHours;
my $subject;
my $from;
my $NewSubject;
my $frombody;
my $cs_recipient;

chomp ($mailserver, $username, $password);

$pop3    = Net::POP3->new($mailserver)       or die "Failed to connect to $mailserver";
$tot_msg = $pop3->login($username,$password) or die "Failed to authenticate $username";

printf("\n   There are $tot_msg messages\n\n");
exit 0 if ("$tot_msg" == 0 );
open (OUT, '>/usr/local/bin/jira.log');
$msgList = $pop3->list();
foreach $msg (keys(%$msgList))
   {
   $header = $pop3->top($msg, 0);
   $frombody = $pop3->get($msg);
   $PagerCall = 0;
   print OUT "@$frombody\n";
   ($subject, $from) = analyze_header($header);

   # Check closed status in each line of the email body
   $PagerCall = 0;
   $OutOfHours = 0;
   $status = "N";
   for $elem (@$frombody)
      {
       if ($elem =~/closed CSS/)
         {
         $status = "Resolved";
         print "ELEMENT:$elem\n";
         }
         }
       if ($elem =~/Pager Call/)
         {
         $PagerCall = 1;
         }
       if ($elem =~/OOH/)
         {
         $OutOfHours = 1;
         }
      }
   FormatHeader($subject);
   GetJiraTag($subject);
   CreateBody("Resolution: Duplicate\n\n");
   `rm /usr/local/bin/mail.txt`;
   open (OUT, '>/usr/local/bin/mail.txt');
   if ($status eq "Resolved")
     {
     if ($PagerCall)
        {
        print OUT "Subject: Resolved Pager Call: - $tosubject\n";
        }
     elsif ($OutOfHours)
        {
        print OUT "Subject: Resolved Out of Hours: - $tosubject\n";
        }
     else
        {
        print OUT "Subject: Resolved $trackit\n";
        }
     }
   else
     {
     if ($PagerCall)
        {
        print OUT "Subject: Pager Call: - $tosubject\n";
        }
     elsif ($OutOfHours)
        {
        print OUT "Subject: Out of Hours: - $tosubject\n";
        }
     else
        {
        print OUT "Subject: Trackit Number: $trackit\n";
        }
     }
  # Get the extra CC: list from the JIRA email if there is one. This starts with "CitySprint CC:"
  foreach (@$frombody)
     {
     $cs_recipient = "";
     if ($_ =~ /CitySprint CC:/)
        {
        $cs_recipient = "$_\n";
        $cs_recipient =~ s/CitySprint CC: //;  #Remove CitySprint CC: form the line
        $cs_recipient =~ s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/; #Remove leading spaces
        }
     }
   print OUT "From: sihelpdesk\@mycompany.com.au\n";
   print OUT "To: $recipient4\n";
   print OUT "Cc: $recipient2, $recipient3, $recipient1, $cs_recipient\n";
   #print OUT "Cc: $recipient1, $cs_recipient\n";
   #print OUT "To: $recipient1\n";
   print OUT "$body\n";
   my $info = qx(`/bin/cat /usr/local/bin/mail.txt | /usr/sbin/sendmail -t`);

   close(OUT);
   $pop3->delete($msg); # not really deleted until quit is called
   }
$pop3->quit;

sub analyze_header
  {
  my $printout;
  my $header_array_ref = shift;
  my $subject;
  # The subject could take up several lines and we want all not just the first.
  # The Subject: comes just before MIME-Version:
  for (my $i = 0; $i < @$header_array_ref; $i++)
    {
    if (@$header_array_ref[$i] =~ /^Subject:/)
       {
       $printout = 1;
       }
    if (@$header_array_ref[$i] =~ /^MIME-Version:/)
       {
       last;
       }
    if ($printout)
       {
       $subject = $subject."@$header_array_ref[$i]";
       }
    }
  my $header2 = join "", @$header_array_ref;
  my ($from   ) = $header2 =~ /From: (.*)/m;
  return ($subject, $from);
  }

sub FormatHeader
   {
   my $string = shift;
   chomp($string);   #Can't have lines in the subject as this confuses sendmail
   #Need to get the subject minus the [JIRA] (SIH-88) part to add to body
   my $index = index($string, ")");
   $tosubject = substr($string, $index + 2);

   #Then the TrackIt Number from the subject. Cut the trackit from the first part of the subject
   $trackit = substr $tosubject, 0, 6;
   $trackit =~ s|\D||g;
   }

sub CreateBody
   {
   $body = "Dear Customer\n\n";
   if ($status eq "Resolved")
      {
      my $resolution_desc = shift;
      $body = $body . "We would like to inform you that the following job request has been resolved;\n";
      $body = $body . "TrackIt Number: $trackit SI Ref: $jiratag\n\n";
      $body = $body . "$tosubject\n";
      $body = $body . GetResolution($frombody);
      $body = $body . "Kind Regards\n";
      $body = $body . "Customer Services Support\n";
      $body = $body . "Software Integrators\n";
      $body = $body . "support\@mycompany.com.au";
      }
   else
      {
      $body = $body . "Thank you for your support request. Your request has been logged into our Help Desk system:\n\n";
      $body = $body . "TrackIt Number: $trackit\n\n";
      $body = $body . "SI Reference: $jiratag\n\n";
      $body = $body . "$tosubject\n\n";
      $body = $body . "A support consultant will be in contact with you soon. Should you have any queries to do with this job,\n";
      $body = $body . "please do not hesitate to contact us at support\@mycompany.com.au using the job number as reference.\n\n";
      $body = $body . "Kind Regards\n";
      $body = $body . "Customer Services Support\n";
      $body = $body . "Software Integrators\n";
      $body = $body . "support\@mycompany.com.au";
      }
   }
sub GetJiraTag
   {
   # In format (SIH-45)
   my $string  = shift;
   my $start = index($string, "(");
   my $end = index($string, ")");
   $jiratag = substr($string, $start + 1, $end - $start - 1);
   }

sub GetResolution
   {
   my $start = 0;
   my $body = shift;
   my $resolution_info;
   my $trimmed;
   foreach (@$frombody)
      {
      if ($_ =~ /^>/)
        {
        $resolution_info = $resolution_info . "\n\n";
        last;
        }
      if ($start)
        {
        $trimmed = $_;
        if ($trimmed =~ /CitySprint CC:/)
           {
           next;
           }
        $trimmed =~  s/^\s*(\S*(?:\s+\S+)*)\s*$/$1/;
        $resolution_info = $resolution_info . "$trimmed\n";
        }
      if ($_ =~ /----------/)
        {
        $start = 1;
        }
      }
   return $resolution_info;
   }

