#!/usr/bin/env perl

use warnings;
use strict;
use Carp;
use HTFeed::Config;
use HTFeed::DBTools qw(get_dbh);

# get time of last delete mail
my $last_delete_sse = previous_time();
my $last_delete_str = `date -d \@$last_delete_sse`;
chomp $last_delete_str;
print "Last delete notification mail: $last_delete_str\n";

# how many deleted since last mail
my $sth = get_dbh()->prepare(q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > FROM_UNIXTIME(?)|);
$sth->execute($last_delete_sse);
my ($count) = $sth->fetchrow_array();
print "Deleted since last notification mail: $count\n";

# how many deleted
my @delete_cnt_queries =
(["today",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > CURRENT_DATE()|],
["yesterday",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) AND delete_t < CURRENT_DATE()|],
["this week [Mon-Sun]",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)|],
["last week [Mon-Sun]",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > DATE_SUB(DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY), INTERVAL 1 WEEK) AND delete_t < DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)|],
["this month",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > DATE_FORMAT(NOW() ,'%Y-%m-01')|],
["last month",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t > DATE_SUB(DATE_FORMAT(NOW() ,'%Y-%m-01'), INTERVAL 1 MONTH) AND delete_t < DATE_FORMAT(NOW() ,'%Y-%m-01')|],
["the beginning of time",q|SELECT COUNT(*) FROM feed_dataset_tracking WHERE delete_t IS NOT NULL|]);

foreach my $pair (@delete_cnt_queries) {
    my ($qname,$q) = @{$pair};
    my $sth = get_dbh()->prepare($q);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    print "Deleted since $qname: $count\n";
}

# get timestamp for the last time deletes report was generated
sub previous_time{
    my $time = shift;
    my $timestamp_file = get_config('dataset'=>'path') . '/conf/delete_report_timestamp';

    # get time
    if(! defined $time){
        open FILE, $timestamp_file or (croak "Couldn't open timestamp file: $timestamp_file $!");
        $time = join("", <FILE>);
        chomp $time;
        return $time
            if (validate_time($time));
        croak "Timestamp file invalid!";
    }
}

sub validate_time{
    my $time = shift;
    return 1
        if($time =~ /^\d+$/ and $time > 0 and time < (2**31));
    return;
}

