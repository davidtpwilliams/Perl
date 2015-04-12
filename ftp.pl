#!/usr/bin/perl
use strict;
use Net::FTP;
use File::Copy;
#
# !!! Following variables are needed
my $directory="/data/caust/IPEC";
my $archive="/data/caust/IPEC_Archive";
my $logfile="/data/caust/logs/ftp.log";
my $destination="yourcompanyipec";
my $login="yourcompany";
my $password="yourcompany";
my $putdir="/dataimport/yourcompanyonline";

#
# program starts here
#
my $ftp;
my $newerr;
my @files;
my $file;
my $filecount;
my $line;
my $lite=0;
my $noeol;
my $date;
my $newlocation;
my $Count = 0;
my @FileList;
my @FileExist;

chdir($directory) or die("$! Can't cd to $directory");

   @files=();
   $newerr=0;

   foreach(<*>) {
          push @files,$_;
   }
   my $filecount=@files;

   if  (not $filecount) {
            exit;
   }
   logit("Files to transfer = $filecount");
   logit("IN DIRECTORY     TRANSFERRED      CONFIRMED",1) ;
   logit("------------     -----------      -------------", 1);

   $ftp=Net::FTP->new($destination,Timeout=>240) or $newerr=1;
        if ($newerr) {
             logit("ERROR: Can't connect to $destination");
           $ftp->quit;
           exit;
        }
   $ftp->login("$login","$password") or $newerr=1;
        if ($newerr) {
          logit("ERROR: Can't login  $destination with $login,$password");
         $ftp->quit;
         exit;
        }
   $ftp->binary(); # set binary mode
   $ftp->cwd($putdir) or $newerr=1;
        if ($newerr) {
          logit("ERROR: Can't cd to $putdir on  $destination");
          $ftp->quit;
          exit;
        }

   foreach(@files) {
   $file=$_;
      $newerr=0;
      logit("$file  - ", 1,1);
      $ftp->put($file,$file) or $newerr=1;
      if ($newerr) {
        logit("ERROR: Error transferring $file");
      } else {
         $Count++;
         # !!! Save the processed file to an archive
         $newlocation = "$archive/$file";
         move($file, $newlocation);
         logit("$file  - ", 1,1);

         # Get list of remote files and check for file just transferred
	 @FileList = $ftp->ls or logit("Could not get file list\n",1);
         @FileExist = grep (/$file/i, @FileList);
         logit("@FileExist", 1);
      }
   }
logit("Number of files transferred = $Count");
if ($Count != $filecount)
   {
   logit("ERROR: Not all files transferred");
   }
logit("================================================",1);

sub logit {
  $line=shift;
  $lite=shift;
  $noeol=shift;
  $date=localtime(time);
  open(LOG,">>$logfile") or die("$! Can't open $logfile");
  if ($lite)
     {
     if ($noeol)
	{
	print LOG "$line";
	}
     else
	{
        print LOG "$line\n";
	}
     }
  else
     {
     print LOG "$date: $line\n";
     }
  close LOG;
}
