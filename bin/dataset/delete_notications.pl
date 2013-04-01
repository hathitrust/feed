#!/usr/bin/env perl

use warnings;
use strict;

use Carp;
use Getopt::Long;
use Pod::Usage;
use Switch;
use Mail::Mailer;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::DBTools qw(get_dbh);
use HTFeed::Config;

# runmodes
my ($since_date,$all,$update);
# other flags
my ($dryrun,$preserve_timestamp,$help);
# strings
my $to_address;

GetOptions(
    'since=s'  => \$since_date,
    'all'      => \$all,
    'update'   => \$update,
    'dry-run'  => \$dryrun,
    'preserve-timestamp' => \$preserve_timestamp,
    'address=s'  => \$to_address,
    'help|?' => \$help,
) or pod2usage(2);
pod2usage(1) if $help;

# allow exactly 1 runmode flag
my $runmode_flag_cnt = 0;
$runmode_flag_cnt++ if(defined $since_date);
$runmode_flag_cnt++ if($all);
$runmode_flag_cnt++ if($update);
pod2usage(2)
    unless($runmode_flag_cnt == 1);

if($all){
    pod2usage(-msg => '--all flag only allowed in dry-run mode, or with explicit email address', -exitval => 2) 
        unless($dryrun or $to_address);
}

validate_time($since_date) or croak 'invalid datestamp supplied'
    if(defined $since_date);

# set default to_address AFTER all / explicit address check above
$to_address = 'hathitrust-datasets-alerts@umich.edu'
    unless ($to_address);

# dry-run implies preserve-timestamp
$preserve_timestamp = 1
    if($dryrun or !$update);

my $new_timestamp = get_db_time();

my $sth;
if($all){
    $sth = get_dbh()->prepare(q|SELECT CONCAT(namespace,'.',id) FROM feed_dataset_tracking WHERE delete_t IS NOT NULL|);
    $sth->execute();
}
else{
    my $time = ($since_date or previous_time());
    $sth = get_dbh()->prepare(q|SELECT CONCAT(namespace,'.',id) FROM feed_dataset_tracking WHERE delete_t > FROM_UNIXTIME(?)|);
    $sth->execute($time);
}

my $ids = $sth->fetchall_arrayref();
my $id_count = @{$ids};

unless($id_count){
    print "No deletes\n";
    unless($preserve_timestamp){
        previous_time($new_timestamp);
    }
    exit 0;
}
else{
    my @flattened_ids = map { @$_ } @{$ids};
    my $id_str = join("\n",@flattened_ids);
    if($dryrun){
        print "$id_str\n";
        exit 0;
    }

    # write email
    my $email_text = <<'END';
Dear HathiTrust dataset recipients,

What follows is a list of HathiTrust volumes that no longer meet the criteria for inclusion in our datasets. In accordance with our terms of use, please remove these volumes from any datasets you have downloaded from us. If you obtained your datasets from us via rsync, and you only maintained that one copy, a simple rsync refresh (using --delete as instructed) will suffice. Others will have to determine how best to meet this requirement.

If you no longer possess HathiTrust datasets, or if you have other questions regarding datasets, then please email feedback@issues.hathitrust.org.

Thank you.

HathiTrust
END

    $email_text .= "\n===BEGIN ID LIST===\n$id_str\n===END ID LIST===\n";

    # send email
    my $mailer = new Mail::Mailer;
    $mailer->open({ 'From' => 'Feedback@issues.hathitrust.org',
                    'Subject' => 'HathiTrust dataset volume delete notice',
                    'Reply-To' => 'Feedback@issues.hathitrust.org',
                    'To' => $to_address});                

    print $mailer $email_text;

    $mailer->close() or croak("Couldn't send message: $!");

    unless($preserve_timestamp){
        previous_time($new_timestamp);
    }
}

sub validate_time{
    my $time = shift;
    return 1
        if($time =~ /^\d+$/ and $time > 0 and time < (2**31));
    return;
}

# get current unix timestamp from database server
sub get_db_time{
    my $sth = get_dbh()->prepare('SELECT UNIX_TIMESTAMP()');
    $sth->execute();
    my ($time) = $sth->fetchrow_array();
    return $time
        if (validate_time($time));
    croak 'Could not get current timestamp from database';
}

# get/set timestamp for the last time deletes report was generated
sub previous_time{
    my $time = shift;
    my $timestamp_file = get_config('dataset'=>'path') . '/conf/delete_report_timestamp';

    # get time
    if(! defined $time){
        open FILE, $timestamp_file or croak "Couldn't open timestamp file: $!";
        $time = join("", <FILE>);
        chomp $time;
        return $time
            if (validate_time($time));
        croak "Timestamp file invalid!";
    }

    # set time
    else{
        validate_time($time) or croak "Cannot set deletes timestamp file to invalid time: $time";
        open (FILE, ">$timestamp_file");
        print FILE $time;
        close (FILE);
    }
}

__END__

=head1 NAME

delete_notications.pl - send email notifications to users of HathiTrust datasets concerning dataset deletes

=head1 SYNOPSIS

delete_notications.pl <--all | --update [--preserve-timestamp] | --since DATE> [--dry-run] [--address]

--all - Send list of all deletes since the beginning of time (--dry-run or --address flags required with this flag)

--update - Send list of all deletes since time contained in the delete_report_timestamp file; the usual mode of operation

--preserve-timestamp - Do not update the timestamp file

--since DATE - Send list of all deletes since DATE - specfied in SSE

--dry-run - Print report to stdout rather than email, implies --preserve-timestamp if used with --update

--address - email address to send report to, ususaly used with --update --preserve-timestamp or --since DATE

=cut
