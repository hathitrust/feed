#!/usr/bin/perl -w

use strict;
use DBI;
use Time::localtime;
use HTFeed::Email;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);

=head1 NAME

deposit_barcode_list.pl

=head1 SYNOPSIS

% perl deposit_barcode_list.pl

=head1 DESCRIPTION

This script dumps any barcodes ingested before a given time and scp's them to $scphost. It then moves the file to $rights_dir/barcodes_archive/.

This script most likely needs to be run by the user specified in the 'rights_user' config varable.

=cut

my $thisprog = 'deposit_barcode_list';

my $user           = get_config( 'rights', 'user' );
my $rights_dir     = get_config( 'rights', 'staging' );
my $rights_archive = get_config( 'rights', 'archive' );

my $scpuser              = get_config( 'rights', 'scp', 'user' );
my $scphost              = get_config( 'rights', 'scp', 'host' );
my $barcodes_deposit_dir = get_config( 'rights', 'scp', 'deposit_dir' );

print "$thisprog -INFO- START: " . CORE::localtime() . "\n";

my $now = localtime();

my $date = sprintf( "%04d-%02d-%02d_%02d-%02d-%02d",
    ( 1900 + $now->year() ),
    ( 1 + $now->mon() ),
    $now->mday(),
    $now->hour,
    $now->min,
    $now->sec
);

#
# Make sure this script is being run by the right user
#
my $whoami = `whoami`;
chomp($whoami);

if ( $whoami ne $user ) {
    die("$thisprog -ERR- Must be run as $user (not $whoami)\n");
}

#
# Scp barcodes file and move to archive directory
#

if ( !-d $rights_archive ) {
    mkdir("$rights_archive");
}


my $dbh = get_dbh();

# 24 hours + 2 for last sync to run (needed if active volume was the last sync to run)
$dbh->begin_work();
my $sth = $dbh->prepare(
q(SELECT namespace,id FROM queue WHERE status = 'collated' FOR UPDATE)
# "SELECT ns,objid FROM queue WHERE status = 'collated' AND TIMEDIFF(CURRENT_TIMESTAMP,update_stamp) > '26:00:00' FOR UPDATE"
);
my $upd_sth = $dbh->prepare(
q(UPDATE queue SET status = 'barcode_deposited' WHERE namespace = ? and id = ?)
);
$sth->execute();
my $rows = $sth->rows();
my $file = "barcodes_${date}_ingested";
my $printed_barcodes = 0;

if ( $rows > 0 ) {
    print "$thisprog -INFO- $rows barcodes to deposit\n";


    open( my $fh, ">", "$rights_dir/$file" )
      or die("$thisprog -ERR- Can't open $file for writing: $!");

    while ( my ( $namespace, $objid ) = $sth->fetchrow_array() ) {
        $printed_barcodes++;
        print $fh "$namespace.$objid\n";
        $upd_sth->execute( $namespace, $objid );
    }

    my $cmd =
      "scp '$rights_dir/$file' '$scpuser\@$scphost:$barcodes_deposit_dir' 2>&1";

    if ( my $res = `$cmd` ) {
        $sth->rollback();
        die("$thisprog -ERR- scp error depositing barcodes file: $res");
    }

    #
    # Move to archive directory
    #
    $cmd = "mv '$rights_dir/$file' '$rights_archive'";
    if ( my $res = `$cmd` ) {
        die("$thisprog -ERR- mv error: $res");
    }

    #
    # Email notification
    #

    my $email = get_config( 'rights', 'email' );
#    my $email = "aelkiss\@umich.edu";

    my $admin_email = get_config('admin_email');    # Cc GROOVE admin

    my $subject = "New barcodes file(s) available on $scphost";

    my $body =
"The following new barcodes files are available on $scphost in $barcodes_deposit_dir:\n";
    $body .= "   $file $printed_barcodes\n";

    my $email_obj = new HTFeed::Email();

    if ( !$email_obj->send( $email, $subject, $body, $admin_email ) ) {
        die( "Error sending email to $email with subject $subject: "
              . $email_obj->get_error() );
    }

    print "$thisprog -INFO- Deposited $file.\n";

    $dbh->commit();
    $dbh->disconnect();
}
else {
    print "$thisprog -INFO- No barcodes to deposit.\n";
    $sth->rollback();
    $dbh->disconnect();
}

