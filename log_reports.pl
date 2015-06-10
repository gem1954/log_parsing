#!/usr/bin/perl
#
# add reports for sessions and unique visitors
#
use strict;

use Date::Manip;
&Date_Init("TZ=CST");

my(@files, %files_opened, %pages, %unique_visitors, $sessions);

@files = @ARGV;
#@files = ('test_data/Drupal_HPL__ExampleLog','test_data/access_log-20150308','test_data/access_log-20150322',);

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
		my(%log_record);
		#print "\n-----\n$infile\n$line";
        # parse the line from the log
				
		@log_record{'host', 'user', 'cookie', 'date', 'request', 'result', 
		  'size', '8', 'browser_str', '10'} 
			= $line =~ m/("[^\"]*"|\[.*\]|[^\s]+)/g;
		
		$log_record{'browser_str'} =~ s/\A"//;
		$log_record{'browser_str'} =~ s/"\Z//;
		@log_record{'method', 'file', 'protocol'} = $log_record{'request'} =~ /"(\S+)\s*(\S+)\s*(\S+)"/;
		$log_record{'date_obj'} = &ParseDate($log_record{'date'} =~ /\[(.+?)\]/);
		if(0)
		{
			foreach my $key (sort keys %log_record)
			{
				print " +++ $key = $log_record{$key}\n";
			}
		}
		#printf("==- %s\n", &ParseDate($log_record{'date'} =~ /\[(.+?)\]/ ));
		#last;
		# only report success
	    if ($log_record{'result'} =~ /^200/)
	    {
			my($timedate_obj);
			# don't report on these
	        next if($log_record{'file'} =~ /\.gif\Z/i);
	        next if($log_record{'file'} =~ /\.jpg\Z/i);
			next if($log_record{'file'} =~ /\.js\Z/i);
			next if($log_record{'file'} =~ /\.css\Z/i);
			next if($log_record{'file'} =~ /\.ht\Z/i);
			next if($log_record{'file'} =~ /\.png\Z/i);
			next if($log_record{'file'} =~ /\.swf\Z/i);
			next if($log_record{'file'} =~ /\.pac\Z/i);
			
			# count it
	        $pages{$log_record{'file'}}++;
			
			#printf("\n == %s - %s\n\n", $log_record{'date_obj'}, &DateCalc($log_record{'date_obj'},'today')); exit;
			#$str = Delta_Format(&DateCalc($log_record{'date_obj'},'today'),0, '%mt');
			#printf("\n == %s - %s\n\n", $log_record{'date_obj'}, Delta_Format(&DateCalc('today', $log_record{'date_obj'}),2, '%mt')); exit;
			
			if(exists $unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}})
			{
				#printf("== %s - %s (%s)\n", 
				#	$log_record{'host'},,
				#	$log_record{'browser_str'}, 
				#	Delta_Format(&DateCalc($unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}, $log_record{'date_obj'}),2, '%mt')); #exit;
				# compare time of this request with time of last request
				if(Delta_Format(
					&DateCalc(
						$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[3], 
						$log_record{'date_obj'}),
						0,
						'%mt'
					)
					> 15 # 1 for testing, use 15 for production
				)
				{ 
					# add a session if more then 15 min delay
					$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[0]++;
				}
			}
			else
			{
				# add a session
				$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[0]++;
				# save time of first request
				$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[2] = $log_record{'date_obj'};
			}
			# count this pageview
			$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[1]++;
			# save the time of this request
			$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[3] = $log_record{'date_obj'};
	    }
	}
}

{
	my($visits_filename, $VH, $unique_visitors, $visits);
	
	$visits_filename = "visits_detail.csv";
	
	open($VH, '>', $visits_filename) || die;
	
	print $VH join(',', 'IP Address', 'Browser String', 'Sessions', 'Pages','First Visit','Last Visit'), "\n";
	foreach my $host (sort keys %unique_visitors)
	{
		#print "($host)\n";
		foreach my $browser_str (sort keys %{$unique_visitors{$host}})
		{
			#print "\t($browser_str)\n";
			#print "\t\t($unique_visitors{$host}->{$browser_str}[0]) Visits\n";
			#print "\t\t($unique_visitors{$host}->{$browser_str}[1]) Pages\n";
			#print "\t\t($unique_visitors{$host}->{$browser_str}[2]) First\n";
			#print "\t\t($unique_visitors{$host}->{$browser_str}[3]) Last\n";
			$unique_visitors++;
			$visits += $unique_visitors{$host}->{$browser_str}[0];
			print $VH sprintf("%s\n", 
				join(',',
					map{qq("$_")}
					$host,
					$browser_str,
					$unique_visitors{$host}->{$browser_str}[0],
					$unique_visitors{$host}->{$browser_str}[1],
					&UnixDate($unique_visitors{$host}->{$browser_str}[2], '%m/%d/%Y %H:%M:%S'),
					&UnixDate($unique_visitors{$host}->{$browser_str}[3], '%m/%d/%Y %H:%M:%S'),
				)
			);
		}
	}
	print "$unique_visitors Unique Visitors\n$visits Visits\n";
}

{
	my($pages_filename, $PH, $unique_visitors, $visits);
	
	$pages_filename = "pages.csv";
	
	open($PH, '>', $pages_filename) || die;
	
	print $PH join(',', 'Pages', 'Count'), "\n";
	foreach my $page (sort keys %pages)
	{
		print $PH sprintf("%s,%s\n", $page, $pages{$page});
	}
}
# demonstrate sanity
print "\n\n\n###############\n\n";
foreach my $file (@files)
{
    printf("%s => %s\n", $file, $files_opened{$file});
}


