#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../lib";
use SOAP::Lite;
use HTFeed::Config;
use HTFeed::DBTools;
use HTFeed::Volume;
use Mail::Mailer;

my $service = SOAP::Lite->service(get_config('jira','wsdl'));

my $token = $service->login(get_config('jira','username'),get_config('jira','password'));
print "Logged in, token = $token\n";

my $issues = $service->getIssuesFromJqlSearch($token,'"Next Steps" = "HT to queue"',1000);

my $dbh = HTFeed::DBTools::get_dbh();
my $queue_sth = $dbh->prepare("insert into mdp_tracking.book_queue select ht_namespace, barcode, 1, scan_date, process_date, NULL, CURRENT_TIMESTAMP from mdp_tracking.grin where ht_namespace = ? and barcode = ?");

my $grin_sth = $dbh->prepare("select state,overall_error,conditions,src_lib_bibkey from mdp_tracking.grin where ht_namespace = ? and barcode = ?");

foreach my $issue (@$issues) {
    my $key = $issue->{key};
    print STDERR "Working on $key", "\n";
    my $url = '';
    my @urls;
    # Get the 'item URL' custom field (customfield_10010)
    foreach my $customField ( @{$issue->{'customFieldValues'}} ) {
        if($customField->{'customfieldId'} eq 'customfield_10040') {
            $url = $customField->{'values'}->[0];
            @urls = split(/\s*;\s*/, $url);
        }
    }

    my @results;
    my $had_error = 0;

    if(!@urls) {
        print STDERR "Item URL missing/empty?\n";
        push(@results,"Item URL missing/empty?");
        $had_error++;
    }

    foreach my $url (@urls) {

        # Try to extract ID from item ID
        my $id = $url;
        if($url =~ /babel.hathitrust.org.*id=(.*)/) {
            $id = $1;
        } elsif($url =~ /hdl.handle.net\/2027\/(.*)/) {
            $id = $1;
        }

        if($id !~ /(\w{0,4})\.(.*)/) {
            push(@results,"Couldn't extract object ID from '$id'\n");
            $had_error++;
            next;
        } 

        # Check that the found namespace/objid is valid
        my ($namespace,$objid) = ($1,$2);
        print STDERR "\tWorking on $namespace.$objid\n";
        eval {
            my $volume = new HTFeed::Volume(packagetype => 'google',
                namespace => $namespace,
                objid => $objid);
        };
        if($@) {
            push (@results,"Bad ID '$namespace.$objid': $@");
            $had_error++;
            next;
        }

        # Check GRIN to make sure object is enqueuable
        $grin_sth->execute($namespace,$objid);
        my ($state,$err,$condition,$src) = $grin_sth->fetchrow_array();
        if(not defined $state) {
            push(@results,"$namespace.$objid not found in GRIN");
            $had_error++;
            next;
        }
        if($state ne 'CONVERTED' && $state ne 'NEW' && $state ne 'PREVIOUSLY_DOWNLOADED' && $state ne 'IN_PROCESS') {
            push (@results,"$namespace.$objid has unexpected GRIN state $state");
            $had_error++;
            next;
        }
        if(defined $src and $src ne '') {
            push (@results,"$namespace.$objid appears to be a surrogate: $src");
            $had_error++;
            next;
        }

        # Enqueue
        my $outcome;

        eval {
            my $rows = $queue_sth->execute($namespace,$objid);
            if($rows eq '0E0') {
                push (@results,"$namespace.$objid unexpected error queueing -- couldn't queue even though found in GRIN?");
                $had_error++;
            } else {
                push (@results,"$namespace.$objid queued");
            }
        };
        if($@) {
            if($@ =~ /Duplicate entry/) {
                push (@results, "$namespace.$objid already in queue");
            } else {
                push (@results, "$namespace.$objid error queueing -- $@");
            }
        }

    }

    # Send mail to update ticket
    my $mailer = new Mail::Mailer;
    my $next_steps = ($had_error ? "UM to investigate further" : "HT to reingest");
    my $comment = join("\n",@results);
    $mailer->open({ 'From' => 'aelkiss@umich.edu',
        'Subject' => "($key): Queueing results",
        'To' => 'feedback@issues.hathitrust.org' });

    print $mailer <<EOT;

Next Steps: $next_steps

$comment

EOT
    $mailer->close() or warn("Couldn't send message: $!");

}

