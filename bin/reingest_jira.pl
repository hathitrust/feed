#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use SOAP::Lite;
use HTFeed::Config;
use HTFeed::DBTools;
use HTFeed::Volume;
use Mail::Mailer;
use Getopt::Long;

my $dry_run = 0;

GetOptions ("dry-run|n" => \$dry_run);

if($dry_run) {
    print "Dry run -- not updating jira or queue\n";
} 

my $service = SOAP::Lite->service(get_config('jira','wsdl'));

my $token = $service->login(get_config('jira','username'),get_config('jira','password'));
print "Logged in, token = $token\n";

process_issues('"Next Steps" = "Google to reanalyze"',\&reanalyze_handler,'HT to reingest','UM to investigate further');
process_issues('"Next Steps" = "Google to re-process"',\&reprocess_handler,'HT to reingest','UM to investigate further');
process_issues('"Next Steps" = "HT to queue"',\&queue_handler,'HT to reingest','UM to investigate further');
process_issues('"Next Steps" = "HT to reingest"',\&reingest_handler,'UM to investigate further');


sub process_issues {
    my $query = shift;
    my $callback = shift;
    my $good_result = shift;
    my $bad_result = shift;
    my $issues = $service->getIssuesFromJqlSearch($token,$query,1000);

    print "\n", "-" x 80, "\n";
    print "Finding issues with $query\n";
    print "-" x 80, "\n\n";

    foreach my $issue (@$issues) {
        my $key = $issue->{key};
        print "Working on $key", "\n";
        my $url = '';
        my @results;
        my $had_error = 0;
        my $should_report = 1;

        my @urls = get_item_urls($issue);

        if(!@urls) {
            print "Item URL missing/empty?\n";
            push(@results,"Item URL missing/empty?");
            $had_error++;
        }

        foreach my $url (@urls) {
            # trim whitespace from URL
            $url =~ s/^\s*(\S+)\s*$/$1/g;
            print "Working on $url\n";
            my ($volume, $namespace, $objid);
            eval {
                $volume = extract_volume($url);
                $namespace = $volume->get_namespace();
                $objid = $volume->get_objid();
            };
            if($@) {
                push (@results,"Bad ID for $url: $@");
                $had_error++;
                next;
            }
            my $res = &$callback($volume);
            push(@results,@{$res->{results}});
            $had_error += $res->{error};
            # only report if every issue says we should report
            $should_report = 0 if !$res->{report};

        }

        my $next_steps = ($had_error ? $bad_result : $good_result);
        if(!$dry_run and $should_report) {
            # Send mail to update ticket
            my $mailer = new Mail::Mailer;
            my $comment = join("\n",@results);
            print "$key next step: $next_steps\n $comment\n\n";
            $mailer->open({ 'From' => 'aelkiss@umich.edu',
                    'Subject' => "($key): results",
                    'To' => 'feedback@issues.hathitrust.org' });

            print $mailer <<EOT;

Next Steps: $next_steps

$comment

EOT
$mailer->close() or warn("Couldn't send message: $!");
        }

        $next_steps = 'No status change' if not defined $next_steps or !$should_report;
        print "($key): $next_steps - error = $had_error, report = $should_report\n";
        print join("\n",@results);
        print "\n\n";

    }
}




# -------------------

sub get_item_urls {
    my $issue = shift;
    my @urls;
    # Get the 'item URL' custom field (customfield_10010)
    foreach my $customField ( @{$issue->{'customFieldValues'}} ) {
        if($customField->{'customfieldId'} eq 'customfield_10040') {
            my $url = $customField->{'values'}->[0];
            @urls = split(/\s*;\s*/, $url);
        }
    }
    return @urls;
}

# Extract the item ID and create a volume from the item URL
sub extract_volume {
    # Try to extract ID from item ID
    my $url = shift;
    my $id = $url;
    if($url =~ /babel.hathitrust.org.*id=(.*)/) {
        $id = $1;
    } elsif($url =~ /hdl.handle.net\/2027\/(.*)/) {
        $id = $1;
    }

    $id =~ /(\w{0,4})\.(.*)/ or die("Can't parse item URL");

    return new HTFeed::Volume(packagetype => 'google',
        namespace => $1,
        objid => $2);
}

sub get_grin_info {
    my $volume = shift;
    my $grin_instance = $volume->get_nspkg()->get('grinid');
    my $grin_id = uc($volume->get_objid());

    my $url = "https://books.google.com/libraries/$grin_instance/_barcode_search?execute_query=true&barcodes=$grin_id&format=text&mode=full";
    my $res = `curl -s '$url'`;

    my @lines = split("\n",$res);

    if(@lines != 2) {
        warn("Can't get GRIN info for $grin_instance:$grin_id: $res");
        return undef;
    } else {
        my @splitlines = map { [ split("\t",$_) ] } @lines;
        return { map { $splitlines[0][$_] => $splitlines[1][$_] } ( 0..$#{$splitlines[0]} ) };
    }


}

sub queue_handler {

    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();

    my $had_error = 0;
    my @results = ();

    # Check GRIN to make sure object is enqueuable
    my $grin_info = get_grin_info($volume);
    my $zip_file = $volume->get_repository_zip_path();
    if($zip_file and -e $zip_file) {
        my $zipdate = (stat($zip_file))[9];
#            push (@results,"$namespace.$objid zip file date is " . scalar(localtime($zipdate)));
    } else {
        push (@results,"$namespace.$objid not previously ingested");
    }
#        push (@results,"$namespace.$objid download date is $dl_date") if defined $dl_date; 
#        push (@results,"$namespace.$objid process date is $process_date") if defined $process_date;
#        push (@results,"$namespace.$objid analyze date is $analyze_date") if defined $analyze_date;
    my $reanalyzed = ($grin_info->{'Analyzed Date'} gt $grin_info->{'Converted Date'});
    my $reprocessed = ($grin_info->{'Processed Date'} gt $grin_info->{'Converted Date'});
    push (@results,"$namespace.$objid has been analyzed since it was last downloaded") if $reanalyzed;
    push (@results,"$namespace.$objid has been processed since it was last downloaded") if $reprocessed;

    my $res = check_grin_common($volume,$grin_info);
    push(@results,@{$res->{results}});
    $had_error += $res->{error};

    if(defined $reprocessed and !$reprocessed and defined $reanalyzed and !$reanalyzed) {
        push (@results,"$namespace.$objid has not been processed or analyzed since downloading -- not queueing\n");
        $had_error++;
    }

    # Enqueue
    if(!$had_error) {
        my $res = queue_volume($volume,$grin_info);
        push(@results,@{ $res->{results} });
        $had_error += $res->{error};
    }

    return {
        results => \@results,
        error => $had_error,
        report => 1,
    }

}

sub check_grin_common {
    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $grin_info = shift;
    my @results = ();
    my $had_error = 0;

    my $state = $grin_info->{'State'};
    my $src = $grin_info->{'Source Library Bibkey'};
    if(not defined $state) {
        push(@results,"$namespace.$objid not found in GRIN");
        $had_error++;
    }
    elsif($state ne 'CONVERTED' && $state ne 'NEW' && $state ne 'PREVIOUSLY_DOWNLOADED' && $state ne 'IN_PROCESS') {
        push (@results,"$namespace.$objid has unexpected GRIN state $state\n");
        $had_error++;
    }
    if(defined $src and $src ne '') {
        push (@results,"$namespace.$objid appears to be a surrogate: $src\n");
        $had_error++;
    }

    return { results => \@results,
    error => $had_error };
}

sub reingest_handler {

    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my @results = ();
    my $report = 1;

    my $dbh = HTFeed::DBTools::get_dbh();
    my $queue_status_sth = $dbh->prepare("select datediff(CURRENT_TIMESTAMP,q.lastupdate) as age, g.state, q.statusid, s.status_description, q.lastupdate, es.error_name, e.description from mdp_tracking.book_queue q left join mdp_tracking.errors e on q.namespace = e.namespace and q.barcode = e.barcode join mdp_tracking.status s on q.statusid = s.statusid join mdp_tracking.grin g on q.barcode = g.barcode and q.namespace = g.ht_namespace left join mdp_tracking.error_status es on e.errorid = es.errorid where q.namespace = ? and q.barcode = ?;");

    # Check GRIN to make sure object is enqueuable
    $queue_status_sth->execute($namespace,$objid);
    my ($age, $state, $statusid, $statusdesc, $lastupdate, $errorid, $errordesc) = $queue_status_sth->fetchrow_array();
    if(not defined $age) {
        # Not in queue, so hopefully reingested. Get date from filesystem
        my $zip_file = $volume->get_repository_zip_path();
        if(-e $zip_file) {
            my $date = (stat($zip_file))[9];
            if(time() - $date < 86400) {
                # wait to report - zip file not yet synched
                $report = 0;
            } 
            push(@results,"$namespace.$objid ingested; zip file date " . scalar(localtime($date)));
        } else {
            push(@results,"$namespace.$objid not in queue, but not in repository either");
        }
    } else {
        # Still in the queue. Was there an error?
        if($statusid eq  '9') {
            push(@results,"$namespace.$objid failed ingest in $errorid: $errordesc");
        }
        # Has it been sitting in the queue too long?
        elsif($age > 7) {
            push(@results,"$namespace.$objid stuck in queue -- status is '$statusdesc' last updated $lastupdate; GRIN state is $state");
        } else {
            $report = 0;
            push(@results,"$namespace.$objid waiting for reingest -- status is '$statusdesc' last updated $lastupdate; GRIN state is $state");
        }
    }

    return { 
        results => \@results,
        error   => 0,
        report  => $report
    };

}

sub reanalyze_handler {
    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $grin_info = get_grin_info($volume);
    my @results = ();
    my $report = 0;
    my $had_error = 0;
    my $reanalyzed = ($grin_info->{'Analyzed Date'} gt $grin_info->{'Converted Date'});
    push (@results,"$namespace.$objid has been analyzed since it was last downloaded") if $reanalyzed;

    my $res = check_grin_common($volume,$grin_info);
    push(@results,@{$res->{results}});
    $had_error += $res->{error};

    # only report if volume has been analyzed
    if($reanalyzed and !$had_error) {
        $report = 1;
        my $res = queue_volume($volume,$grin_info);
        push(@results,@{ $res->{results} });
        $had_error += $res->{error};
    }

    return {
        results  => \@results,
        error => $had_error,
        report => $report
    }
}

sub reprocess_handler {
    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $grin_info = get_grin_info($volume);
    my @results = ();
    my $report = 0;
    my $had_error = 0;
    my $reprocessed = ($grin_info->{'Processed Date'} gt $grin_info->{'Converted Date'});
    push (@results,"$namespace.$objid has been processed since it was last downloaded") if $reprocessed;

    my $res = check_grin_common($volume,$grin_info);
    push(@results,@{$res->{results}});
    $had_error += $res->{error};

    # only report if volume has been analyzed
    if($reprocessed and !$had_error) {
        $report = 1;
        my $res = queue_volume($volume,$grin_info);
        push(@results,@{ $res->{results} });
        $had_error += $res->{error};
    }

    return {
        results  => \@results,
        error => $had_error,
        report => $report
    }
}

sub queue_volume {
    my $dbh = HTFeed::DBTools::get_dbh();
    my $queue_sth = $dbh->prepare("insert into mdp_tracking.book_queue (namespace, barcode, statusid, scandate, processeddate, node, lastupdate) values (?, ?, 1, ?, ?, NULL, CURRENT_TIMESTAMP)");

    my $volume = shift;
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();
    my $grin_info = shift;
    my $had_error = 0;

    my @results = ();

    if(!$dry_run) {
        eval {
            my $rows = $queue_sth->execute($namespace,$objid,$grin_info->{'Processed Date'},$grin_info->{'Analyzed Date'});
            if($rows eq '0E0') {
                push (@results,"$namespace.$objid unexpected error queueing\n");
                $had_error++;
            } else {
                push (@results,"$namespace.$objid queued");
                push (@results,"");
            }
        };
        if($@) {
            if($@ =~ /Duplicate entry/) {
                push (@results, "$namespace.$objid already in queue");
            } else {
                push (@results, "$namespace.$objid error queueing -- $@");
            }
        }
    } else {
        print "Dry run - would queue $namespace.$objid\n";
    }

    return { results => \@results,
             error => $had_error };
}
