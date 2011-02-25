#!/usr/bin/perl

use HTFeed::DBTools;

my %namespace_tags = (
    chi => [qw(bib google)],
    coo => [qw(bib google)],
    inu => [qw(bib google)],
    mdl => [qw(local)],
    mdp => [qw(google)],
    miua => [qw(local)],
    miun => [qw(local)],
    njp => [qw(bib google)],
    nnc1 => [qw(bib google)],
    nnc2 => [qw(bib ia)],
    nyp => [qw(bib google)],
    pst => [qw(bib google)],
    uc1 => [qw(bib google)],
    uc2 => [qw(bib ia)],
    ucm => [qw(bib google)],
    uiuo => [qw(bib ia)],
    umn => [qw(bib google)],
    wu => [qw(bib google)],
    yale => [qw(bib local)],
);



my @queries = (
    # # bib records failed in loading - from systems
    # Item records with digital objects - from hathifiles
#    {
#        header => "Item records with digital objects",
#    },
    {
        header => "Item records without digital objects",
        required_tags => [qw(bib)],
        query => <<'SQL'
         SELECT count(*) FROM mdp_tracking.nonreturned 
             WHERE namespace = ?
SQL
    },

    {
        header => "Number of items queued/in process",
        query  => <<'SQL'
          SELECT count(*) FROM mdp_tracking.book_queue 
             WHERE statusid != '9' 
                   AND (namespace, barcode) NOT IN (SELECT namespace, id FROM mdp.rights_current) 
                   AND namespace = ?
SQL
    },
    {
        header => "Number of items stuck in process (no action in 5 days)",
        query  => <<'SQL'
          SELECT count(*) FROM mdp_tracking.book_queue 
            WHERE statusid NOT IN ('9','13','14') 
                  AND datediff(CURRENT_TIMESTAMP,lastupdate) >= 5 
                  AND namespace = ?
SQL
    },
    {
        header => "Number of items with bib data but NOT IN GRIN",
        required_tags => [qw(bib google)],
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.nonreturned 
            WHERE (namespace, barcode) NOT IN (SELECT ht_namespace, barcode FROM mdp_tracking.grin) 
                  AND namespace = ?
SQL
    },
    {
        header => "NOT_AVAILABLE_FOR_DOWNLOAD (with or without bib data)",
        required_tags => [qw(google)],
        query => <<'SQL'
            SELECT count(*) FROM mdp_tracking.grin
              WHERE state = 'NOT_AVAILABLE_FOR_DOWNLOAD' 
                    AND ht_namespace = ?
SQL
    },
    {
        header => "CHECKED_IN (with or without bib data)",
        required_tags => [qw(google)],
        query  => <<'SQL'
            SELECT count(*) FROM mdp_tracking.grin 
                WHERE state = 'CHECKED_IN' 
                AND ht_namespace = ?
SQL
    },
    {
        header => "High error (with or without bib data)",
        required_tags => [qw(google)],
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.grin 
            WHERE overall_error > 15 
                  AND ht_namespace = ?
SQL
    },
    {
        header => "Duplicate (with or without bib data)",
        required_tags => [qw(google)],
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.grin 
            WHERE src_lib_bibkey IS NOT NULL 
                  AND ht_namespace = ?
SQL
    },
    {
        header => "Available on GRIN AND not high error or duplicate, but missing bib data",
        required_tags => [qw(bib google)],
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.grin g 
            WHERE state IN ('NEW','CONVERTED','PREVIOUSLY_DOWNLOADED','IN_PROCESS') 
                  AND (ht_namespace,barcode) NOT IN (SELECT namespace,barcode FROM mdp_tracking.book_queue) 
                  AND (ht_namespace,barcode) NOT IN (SELECT namespace,barcode FROM mdp_tracking.nonreturned) 
                  AND (ht_namespace,barcode) NOT IN (SELECT namespace,id FROM mdp.rights_current) 
                  AND overall_error <= 15 
                  AND src_lib_bibkey is NULL 
                  AND ht_namespace = ?
SQL
    },
    {
        header => "Number of items failing validation/ingest (total) ",
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.book_queue 
            WHERE statusid = '9' 
              AND namespace = ?
SQL
    },
    {
        header => "Number of items failing validation/ingest (attempted last 7 days)",
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking.book_queue 
            WHERE statusid = '9'
             AND datediff(CURRENT_TIMESTAMP,lastupdate) <= 7
             AND namespace = ? 
SQL
    },
    {
        header => "Number of items ingested (this week)",
        command => "grep -c ingested /htapps/babel/groove/prep/reports/%s*.csv"
    },
    {
        header => "Number of items ingested (total)",
        query => <<'SQL'
          SELECT count(*) FROM mdp_tracking_new.fs_log 
            WHERE namespace = ?
SQL
    }
    # number of items ingested total - from fs log?
);

my $dbh = HTFeed::DBTools::get_dbh();

print "Namespace," .  join(',', map { '"' . $_->{header} . '"' } @queries) . "\n";

foreach my $namespace (sort keys(%namespace_tags)) {
    my $tags = $namespace_tags{$namespace};
    my @query_results = ($namespace);

    foreach my $query (@queries) {
        if(tagmatch($tags,$query->{required_tags})) {
            my $count = 0;
            if(exists $query->{query}) {
                my $sql = $query->{query};
                my $sth = $dbh->prepare($sql);
                $sth->execute($namespace);
                my @results = $sth->fetchrow_array();
                $count = $results[0];
            }
            elsif(exists $query->{command}) {
                my $cmd = sprintf($query->{command},$namespace);
                $count = `$cmd`;
                chomp($count);
                $count = 0 if $count eq '';
            }
            $query->{count} += $count;
            push(@query_results,$count);
        } else {
            push(@query_results,"N/A");
        }
    }
    print join(',',@query_results), "\n";
}

print "Total,".  join(',', map { $_->{count} } @queries ). "\n";

# checks that all elements of expected are in actual
sub tagmatch {
    my $actual = shift;
    my $expected = shift;

    my $ok = 1;
    foreach my $tag (@$expected) {
        if(!grep { $_ eq $tag } @$actual) {
            $ok = 0;
            last;
        }
    }

    return $ok;
}
