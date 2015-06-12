#!/usr/bin/perl

use strict;

my(@files, %files_opened, %pages);

@files = @ARGV;

unless(-e $files[0])
{
	print "\n\n\tUsage $0 <log file> [<log file> <log file> ..]\n\t\tif log files end in 'gz' they will be treated as gzipped\n";
	exit;
}

foreach my $infile (@files)
{
	# keep some sembalance of sanity
	$files_opened{$infile}++;
	
	# open the files for reading
	my($I);
	if($infile =~ /gz\Z/)
	{
		# zipped file
		open($I,"gzip -dc $infile|") || die "cannot open '$infile'";
	}
	else
	{
		# text file
		open($I,$infile) || die "cannot open '$infile'";
	}

    while (my $line = <$I>)
    {
        # parse the line from the log
	    my($host,$time,$request,$result,$file,$cookie,
	      $c_host,$c_int);
	    $line =~ s/(\S+)[^"]+//;
	    $host = $1;
	    $line =~ s/"(\S+)"[^\[]+//;
	    $cookie = $1;
	    $line =~ s/\[(.*?)\]\s*//;
	    $time = $1;
	    $line =~ s/"(.*?)"\s*\s*//;
	    $request = $1;
	    $line =~ s/(\d*)\s*//;
	    $result = $1;
	    ($file) = $request =~ m|\w+\s+(/\S+)|;
	    $file =~ s/\?.*//;	 
   
		# only report success
	    if ($result =~ /^200/)
	    {
			# don't report on these
	        next if($file =~ /\.gif\Z/i);
	        next if($file =~ /\.jpg\Z/i);
			next if($file =~ /\.js\Z/i);
			next if($file =~ /\.css\Z/i);
			next if($file =~ /\.ht\Z/i);
			next if($file =~ /\.png\Z/i);
			next if($file =~ /\.swf\Z/i);
			next if($file =~ /\.pac\Z/i);
			# count it
	        $pages{$file}++;
	    }
    }
}

# report
foreach my $page (sort keys %pages)
{
    printf("%s,%s\n", $page, $pages{$page});
}
# demonstrate sanity
print "\n\n\n###############\n\n";
foreach my $file (@files)
{
    printf("%s => %s\n", $file, $files_opened{$file});
}



