#!/usr/bin/perl
#
# add reports for sessions and unique visitors
#
use strict;

use Date::Manip;
&Date_Init("TZ=CST");

use Getopt::Std;

$| = 1; # don't buffer output

my(%opts, @report_dates, $out_dates, @files, %log_field_maps, $map_used_AR, %files_opened, %pages, 
	%unique_visitors, $sessions, $count);

getopt('SEH', \%opts);

@files = @ARGV;
#@files = ('test_data/access_log-20150308','test_data/access_log-20150322','test_data/Drupal_HPL__ExampleLog',);

%log_field_maps =
(
	'new_apache' => ['host', 'user', 'cookie', 'date', 'request', 'result', 'size', '8', 'browser_str', '10'],
	'old_apache' => ['host', 'user',  'date', 'request', 'result','size', '8', 'browser_str', '10']
);
if(exists $log_field_maps{$opts{'H'}})
{
	$map_used_AR = $log_field_maps{$opts{'H'}};
}
else
{
	$map_used_AR = $log_field_maps{'new_apache'};
}
#@opts{'S', 'E'} = ('3/21/15', '4/1/15');
if(my $start = &ParseDate($opts{'S'}))
{
	$report_dates[0] = $start;
	$out_dates = &UnixDate($start, '%Y_%m_%d')
}
if(my $end = &ParseDate($opts{'E'}))
{
	$report_dates[1] = $end;
	$out_dates .= &UnixDate($end, '-%Y_%m_%d')
}
print "start = $opts{'S'}\nend = $opts{'E'}\nheader = $opts{'H'} ($map_used_AR->[2])\nfile = $files[0]\n\n";
# -S 1 -E 2 -H 3
# -H new_apache
# -H new_apache -S 2/5/14 -E 3/5/14 -- ssss
#exit;

#if(!-e $files[0] || $report_dates[0] =~ /\S/ || $report_dates[1] =~ /\S/ )
#{
#	print "\n\n\tUsage \n$0 -S <start date> -E <end date> [-H <type>] -- <log file> [<log file> <log file> ..]\n\t\tif log files end in 'gz' they will be treated as gzipped\n";
#	exit;
#}
unless(-e $files[0] && $report_dates[0] && $report_dates[1])
{
	print "\n\n\tUsage \n$0 -S <start date> -E <end date> [-H <type>] -- <log file> [<log file> <log file> ..]\n\t\tif log files end in 'gz' they will be treated as gzipped\n";
	exit;
}

print "OK__\n";
#exit;

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
        # parse the line from the log
 
		@log_record{@$map_used_AR}
			= $line =~ m/("[^\"]*"|\[.*\]|[^\s]+)/g;
		
		$log_record{'browser_str'} =~ s/\A"//;
		$log_record{'browser_str'} =~ s/"\Z//;
		@log_record{'method', 'file', 'protocol'} = $log_record{'request'} =~ /"(\S+)\s*(\S+)\s*(\S+)"/;
		$log_record{'date_obj'} = &ParseDate($log_record{'date'} =~ /\[(.+?)\]/);
		
		#print "$report_dates[0] $log_record{'date_obj'} $report_dates[1]\n";
		if($log_record{'date_obj'} lt $report_dates[0])
		{
			#print "\tearly\n";
			next;
		}
		if($log_record{'date_obj'} gt $report_dates[1])
		{
			#print "\tlate\n";
			next;
		}
		print "$report_dates[0] $log_record{'date_obj'} $report_dates[1]\n";
		print "\t OK\n";
		if(0) # test to be sure log is parsed correctly
		{
			$log_record{'file'} =~ s/\?.*//;
			foreach my $key (sort keys %log_record)
			{
				print " +++ $key = $log_record{$key}\n";
			}
			last;
		}
		# only report success
	    if ($log_record{'result'} =~ /^200/)
	    {
			# get rid of query string
			$log_record{'file'} =~ s/\?.*//;
			# don't report on these
	        next if($log_record{'file'} =~ /\.gif\Z/i);
	        next if($log_record{'file'} =~ /\.jpg\Z/i);
			next if($log_record{'file'} =~ /\.jpeg\Z/i);
			next if($log_record{'file'} =~ /\.js\Z/i);
			next if($log_record{'file'} =~ /\.css\Z/i);
			next if($log_record{'file'} =~ /\.ht\Z/i);
			next if($log_record{'file'} =~ /\.png\Z/i);
			next if($log_record{'file'} =~ /\.swf\Z/i);
			next if($log_record{'file'} =~ /\.pac\Z/i);
			next if($log_record{'file'} =~ /\.ico\Z/i);
			# count it
	        $pages{$log_record{'file'}}++;
			
			if(exists $unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}})
			{
				# compare time of this request with time of last request
				if(Delta_Format(
					&DateCalc(
						$unique_visitors{$log_record{'host'}}->{$log_record{'browser_str'}}[3], 
						$log_record{'date_obj'}),
						0,
						'%mt'
					)
					> 15 # in minites 1 for testing, use 15 for production
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
			# report Progress
			printf("%10i - %s\n", $count, $log_record{'date'}) unless($count % 10000);
			$count++;
	    }
	}
}

{
	my($visits_filename, $VH, $unique_visitors, $visits);
	
	$visits_filename = "visits_detail${out_dates}.csv";
	
	open($VH, '>', $visits_filename) || die;
	
	print $VH join(',', 'IP Address', 'Browser String', 'Sessions', 'Pages','First Visit','Last Visit'), "\n";
	foreach my $host (sort keys %unique_visitors)
	{
		foreach my $browser_str (sort keys %{$unique_visitors{$host}})
		{
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
	print "$unique_visitors Unique Visitors\n$visits Visits\n$count Pages";
}

{
	my($pages_filename, $PH, $unique_visitors, $visits);
	
	$pages_filename = "pages${out_dates}.csv";
	
	open($PH, '>', $pages_filename) || die;
	
	print $PH join(',', 'Pages', 'Count'), "\n";
	foreach my $page (sort keys %pages)
	{
		print $PH sprintf("%s,%s\n", $page, $pages{$page});
	}
}
# demonstrate sanity
print "\n###############\n";
foreach my $file (@files)
{
    printf("%s => %s\n", $file, $files_opened{$file});
}


