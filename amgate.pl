#!/usr/bin/perl

use strict;
use File::Copy;
use Fcntl qw(:DEFAULT :flock);

my $process_limit;   #!!! Set by environment variable
my $process;
my @lines;
my $count;
my $Dir;
my $InDir;
my $ResultsDir;
my %files;
my @sorted_files;
my $ProcessFile;
my $ProcessedFile;
my $InProgressDir;
my $line;
my $FailureCount;
my $SuccessCount;
my $LineCount;
my $TotalCount = 0;
my $now;               #!!! time for .status file
my $logtime;            #!!! time for ../logs/amazon/import_PID.log  
my $AmazonLog;
my $ProcessID;

sub lock {
    my ($fh) = @_;
    return flock($fh, LOCK_EX);
}

sub unlock {
    my ($fh) = @_;
    return flock($fh, LOCK_UN);
}

################################################################
#!!! Check environment variables
#!!! Check how many processes are running and if over limit
#!!! exit process
################################################################
sub CheckSetup
{
$process_limit = $ENV{'AMAZON_PROCESS_LIMIT'};
if ($process_limit eq "")
   {
   print  "AMAZON_PROCESS_LIMIT is not set.\n";
   exit;
   }

$process = "amgate.pl";
@lines = `ps -ef | grep $process | grep -v examgate | grep -v process | grep -v grep`;
$count = @lines;

if ($count > $process_limit)    #The current process is counted
  {
  exit;
  }


#!!! Open the Amazon "in" directory and check for files
$Dir = $ENV{'AMAZON_DIRECTORY'};
if ($Dir eq "")
   {
   print  "AMAZON_DIRECTORY is not set.\n";
   exit;
   }
}


#############################################################################
#!!! Open the file and process each line of data.
#!!! Handle any errors returned form call to job_entry
#!!! Update the failure and success counts        
#!!! For successfull updates get the job number and reference
#!!! and add to finishied file.  
#############################################################################
sub ProcessDataFile
{
   $FailureCount = 0;
   $SuccessCount = 0;
   $LineCount = 0;

   #!!! Open log files
   my $ErrorFile = "$Dir/out/$ProcessedFile.error";
   my $FinishedFile = "$Dir/out/$ProcessedFile.finished";
   open (ERRORFILE, ">$ErrorFile")  or die "Can not open error file\n";
   open (FINISHEDFILE, ">$FinishedFile") or die "Can not open finished file\n";

   #!!! Open file read first line and set QUERY_STRING
   open(DATAFILE, "< $InProgressDir/$ProcessFile") 
                   or die "Cannot open manifest file."; #Send to error file.
   while (<DATAFILE>)
      {
      $LineCount++;
      chomp;
      $ENV{REQUEST_METHOD} = "GET";
      $ENV{QUERY_STRING} = $_;

      #!!! Call job_entry to process the data
      open JOBE, "job_entry |" or die "Could not execute program: $!";
      while ( defined( $line = <JOBE> ) )
         {
         chomp($line);

	 #!!! Get the reference number for logging.
         my $datastring = $ENV{QUERY_STRING};
         my $StartPos = index($datastring, "&DT") + 4;
         my $OffSet = index($datastring, "&RE") - $StartPos;
         my $RefNo = substr($datastring, $StartPos, $OffSet);

         if ($line =~ m/\^ER/)
            {
	    $FailureCount++;
            #print "FAILURE: $line\n";
	    print ERRORFILE "$line for reference: $RefNo - line no $LineCount\n";
            #!!! Write to error file with details of error and reference
            #!!! increment error count
            }
         if ($line =~ m/\^JN/)
            {
	    $SuccessCount++;
            #print "SUCCESS: $line\n";
	    #!!! Get the job number
	    my $StartPos = index($line, "^JN") + 3;
	    my $OffSet = index($line, "^BP") - (index($line, "^JN") + 3);
	    my $JobNo = substr($line, $StartPos, $OffSet);

            #!!! print job number and department to file
	    print FINISHEDFILE "$JobNo, $RefNo\n";
            }
         #Evaluate return values
         }
     close JOBE;
     }
     $TotalCount += $LineCount;
     $now = localtime time;
     print STATUSFILE "File name            : $ProcessFile\n";
     print STATUSFILE "No of lines in file  : $LineCount \n";
     print STATUSFILE "No of failures       : $FailureCount\n";
     print STATUSFILE "No of successes      : $SuccessCount\n";
     print STATUSFILE "End Time             :  $now\n";
     close(ERRORFILE);
     close(FINISHEDFILE);
}

#############################################################################
#!!! Loop through the ../in directory and get the oldest .man file
#!!! move this file to the ../inprogress directory 
#!!! Call ProcessDataFile to process each file.
#############################################################################
sub ProcessAmazonDirectory
{
$InDir = "$Dir/in";
my $NoMoreFiles = 0;
my $FilesPresent = 0;
my $TotalRecords = 0;
my $FileCount = 0;
my $OpenLogFile = 1;

until ($NoMoreFiles)
   {
   my $lfh;

   # File locking is use to synchronise access to the in/*.man files.
   # The file is locked, a file selected, moved to the working directory,
   # the lock is release for another program to get the next file.
   open($lfh, "> $InDir/lockfile") 
	  or die "can't open lockfile: $!\n";
   lock($lfh);

   opendir(my $DH, $InDir) or die "Error opening $InDir: $!\n";
   # Get the last modification time of the '.man' files in the directory
   %files = map { $_ => (stat("$InDir/$_"))[9] } 
           grep(! /^\.\.?$/ && m/\.man$/, readdir($DH));

   # sort them on last modification time
   @sorted_files = sort { $files{$a} <=> $files{$b} } (keys %files);
   if (@sorted_files)
      {

      #!!! Print header to log only if file is present 
      if ($OpenLogFile)
         {
	 $OpenLogFile = 0;

         #!!! Get the process ID and use for logging
	 $ProcessID = $$;
	 $AmazonLog = "$ENV{'LOGDIR'}/amazon/import_$ProcessID.log";
	 open (AMAZONLOG, ">>$AmazonLog") or die "Cannot open log file. $!";

	 $logtime = localtime time;
	 print AMAZONLOG "#----------------------------------------\n";
	 print AMAZONLOG "\n";
	 print AMAZONLOG "Start Time           : $logtime\n";
	 }

      # Proceed to process the selected file
      $ProcessFile = "@sorted_files[0]";
      print "Processing file: $ProcessFile\n";
      $FilesPresent = 1;

      #!!! Open the status file, remove .man
      $ProcessedFile =  $ProcessFile;
      $ProcessedFile =~ s/\.man//;
      my $StatusFile = "$Dir/out/$ProcessedFile.status";
      open (STATUSFILE, ">$StatusFile") or die "Can not open status file\n";

      #!!! Note the start time
      $now = localtime time;
      print STATUSFILE "Start Time           : $now\n"; 

      #!!! Move the selected file to the process directory
      $InProgressDir = "$Dir/inprogress";
      move("$InDir/$ProcessFile", $InProgressDir)
              or die "File cannot be copied. $!";

      # release the lockfile
      unlock($lfh);
      close($lfh);

      ProcessDataFile();
      if ($FailureCount)
        {
        print AMAZONLOG "There are errors see $Dir/out/$ProcessedFile.error\n";
        }

      close(STATUSFILE);

      #!!! Save the datafile
      $ResultsDir = "$Dir/out";
      move("$InProgressDir/$ProcessFile", $ResultsDir);
      $FileCount++;
      }
   else
      {
      if ($FilesPresent)
         {
         print AMAZONLOG "All files processed\n"
         }
      else
         {
         closedir($DH);
         }
      $NoMoreFiles = 1;
      }
   closedir($DH);
   }
   print AMAZONLOG "Total no of files processed   = $FileCount\n";
   print AMAZONLOG "Total no of records processed = $TotalCount\n";
   $logtime = localtime time;
   print AMAZONLOG "Finish Time          : $logtime\n";
}

#!!! Check environment variables and whether directory can be opened
CheckSetup();

#!!! Open Amazon ../in and process files if present.
ProcessAmazonDirectory();
