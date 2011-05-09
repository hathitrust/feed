#!/usr/bin/perl -w

#if(-e "/mdp1/etc/g/groove/STOPGROOVE") {
#	exit();
#}

use FindBin;
use lib "$FindBin::Bin/../lib";
use strict;
use HTFeed::Config;
use HTFeed::DBTools;
use Getopt::Long;
use Pod::Usage;

#
# Command line args
#
my $data = 0;
my $archive = 0;
my $rights_dir = undef;
my $note = undef;
my $source_name_cmdline = 'null';
my $force_man = 0;
my $config = undef;
GetOptions("data=s" => \$data,
		   "archive=s" => \$archive,
		   "rights_dir=s" => \$rights_dir,
		   "note=s" => \$note,
		   "source=s" => \$source_name_cmdline,
		   "force_man!" => \$force_man) or pod2usage();


=head1 NAME

populate_rights_data.pl

=head1 SYNOPSIS

perl populate_rights_data.pl [ --data=file | --rights_dir=dir ] 
            --archive=archive_dir

=head2 OPTIONS

  Data load location:

    --data=file gives the full path to the file to load rights from

    --rights_dir=directory gives the path to a directory with rights 
                 files to load; populate_rights will load all the 
                 *.rights files in that directory.

    --archive=archive_dir gives the path to a directory where the
                 loaded .rights files will be saved.

  Other options:
   
    --note="Note" populates the notes field in the database with the
              given note for each loaded rights entry.

    --source=source forces the source for all loaded rights to the
              given source, for example "UMP"

    --force_man allows rights with the rights code "man" to be loaded.

=head1 DESCRIPTION

This script uses the '*.rights' file to populate the rights database, then
moves the '*.rights' file to $rights_archive. The script lists the number
of records that were loaded and prints the info for any rights that were
not loaded, either because the rights were not valid or the rights already
existed in the database.

The script also updates the tracking database to indicate that the rights 
have been successfully loaded for the given volumes.

rights files are tab-separated files in the following format:

namespace id attr reason [user [source]]

where namespace.id is the HathiTrust ID of the volume; attr, reason 
and source are a attribute, reason and source code as listed in the
rights database; and user is the user ID of the user responsible
for generating the rights.

=cut

my $thisprog = 'populate_rights_data';

print "$thisprog -INFO- START: " . CORE::localtime() . "\n";


my $user = `whoami`;
chomp($user);

my %results;  # Structure to keep track of results - which records
              # were created.

#
# Build list of rights data files
#

# Rights files had better be tab-delimited CSV files with no header lines or comments

if($data && ! -e $data) {
	print "$thisprog -ERR- Could not find input file $data\n";
	
	exit(1);	
}

my @rights_files = ();
if(! $data) {

	@rights_files = glob("$rights_dir/*.rights");
}
else {
	push @rights_files, $data;
}


if(! @rights_files) {
	
	print "$thisprog -INFO- No rights files to process.\n";

	exit();
}

#
# Create database handle
#
my $dbh = HTFeed::DBTools::get_rights_dbh();


#
# Prepare SQL statements
#
my $sql = "REPLACE INTO rights_current (namespace, id, attr, reason, source, user, note) VALUES (?, ?, ?, ?, ?, ?, ?)";
my $isth = $dbh->prepare($sql) or die("$thisprog -ERR- Database error: " . $dbh->errstr());

my $ssth = $dbh->prepare("SELECT name FROM reasons WHERE id = (SELECT reason FROM rights_current WHERE namespace = ? AND id = ?)") || die ("$thisprog -ERR- Database error: " . $dbh->errstr());


my $asth = $dbh->prepare("SELECT name FROM attributes WHERE id = (SELECT attr FROM rights_current WHERE namespace = ? AND id = ?)") || die("$thisprog -ERR- Database error: " .  $dbh->errstr());

my $source_sth = $dbh->prepare("SELECT name FROM sources WHERE id = (SELECT source FROM rights_current WHERE namespace = ? AND id = ?)") || die("$thisprog -ERR- Database error: " . $dbh->errstr());

my $queue_delete_sth = $dbh->prepare("DELETE FROM mdp_tracking.book_queue WHERE namespace = ? and barcode = ? and statusid = '18'");
my $queue_update_sth = $dbh->prepare("UPDATE mdp_tracking_new.book_queue SET status = 'done' WHERE namespace = ? and barcode = ? AND status = 'rights'");


foreach my $file (@rights_files) {

	#
	# Open input file for reading
	#
	open(IN, $file) or die("$thisprog -ERR- Could not open $file for reading: $!");

	#
	# Loop through lines of input file...
	#
	while(<IN>) {
		my $line = $_;

		chomp($line);

		# get rid of trailing tab
		$line =~ s/\t$//;
		
		# Format of line had better be:
		#
		#   namespace.barcode attribute reason username source
		#
		# where any of those fields can contain the string
		# /null/i to default to default values. Also, the line
		# could contain less than those fields, like just
		# 'barcode attribute reason username', in which case
		# 'source' will be the default value.
		#

		my ($namespace_and_barcode, $attribute_name, $reason_name, $uniqname, $source_name) = split("\t", $line);

		if(defined $namespace_and_barcode && $namespace_and_barcode !~ /null/i) {
		    $namespace_and_barcode =~ s/\"//g;
		}
		else {
		    die("namespace and barcode missing from input: $namespace_and_barcode");
		}

		# The ? is needed right where it is in the regex below (greedy matching - so the namespace will be everything up to the first period).
		$namespace_and_barcode =~ /(.+?)\.(.+)/ || die("Invalid namespace/barcode: $namespace_and_barcode");

		my $namespace = $1;
		my $barcode = $2;
		
		my $attribute;
		if(defined $attribute_name && $attribute_name !~ /null/i) {
			$attribute_name =~ s/\"//g;

			# Make sure attribute is a valid attribute in the db
			my $hr = $dbh->selectcol_arrayref("SELECT id FROM attributes WHERE name = '$attribute_name'");
			if(! defined $$hr[0]) {
				die("Invalid attribute: $attribute ($barcode)");
			}
			else {
				$attribute = $$hr[0];
			}
		}
		else {
			die("attribute missing from input");
		}

		my $reason;
		if(defined $reason_name && $reason_name !~ /null/i) {
			$reason_name =~ s/\"//g;

			# Make sure reason is a valid reason in the db
			my $hr = $dbh->selectcol_arrayref("SELECT id FROM reasons WHERE name = '$reason_name'");
			if(! defined $$hr[0]) {
				die("Invalid reason: $reason_name ($barcode)");
			}
			else {
				$reason = $$hr[0];
			}
		}
		else {

			# default:
			$reason_name = 'bib';
			my $hr = $dbh->selectcol_arrayref("SELECT id FROM reasons WHERE name = '$reason_name'");
			
			$reason = $$hr[0];
		}

		if(defined $uniqname && $uniqname !~ /null/i) {
			$uniqname =~ s/\"//g;

			if($uniqname =~ /\W/) {
				die("Invalid user: $uniqname for $namespace.$barcode");
			}

			$user = $uniqname;
		}
		else {
			# the default was set above
		}

		my $source;
		if(defined $source_name_cmdline && $source_name_cmdline !~ /null/i) {
			$source_name = $source_name_cmdline;  # source on command line trumps source in input file
		}

		if(defined $source_name && $source_name !~ /null/i) {
			$source_name =~ s/\"//g;

			# Make sure source is a valid value in the db
			my $hr = $dbh->selectcol_arrayref("SELECT id FROM sources WHERE name = '$source_name'");
			if(! defined $$hr[0]) {
				die("Invalid source: $source_name ($barcode)");
			}
			else {
				$source = $$hr[0];
			}
		}
		else {
			# Default source should be whatever the source value was in any previous rights db rows for this ID, or 'google'
			my $hr = $dbh->selectcol_arrayref("SELECT source FROM rights_current WHERE namespace = '$namespace' AND id = '$barcode'");

			if(! defined $$hr[0]) {
				$source = 1; # 'google'
			}
			else {
				$source = $$hr[0];
			}
		}

		
		#
		# Determine if a row already exists for this barcode.
		#
		# If so, if the MOST RECENT 'reason' is anything other
		# than 'bibliographically-derived', don't insert the
		# new record!  We assume that records that were
		# manually set trump bibliographic data. This includes
		# volumes for which access is completely blocked by
		# the 'nobody' attribute, in which case the 'reason'
		# will be 5 - for 'manual access control override...'.
		#
		# Otherwise, insert a new record.
		#
		# 04Sep2007 - Now we get a little smarter: If the MOST RECENT 'reason' is 'bib' and the NEW REASON is anything except man (including bib), then we insert it. Elsif the MOST RECENT 'reason' is anything other than 'bib' or 'man' and the NEW REASON is anything other than 'bib' or 'man' (bib doesn't take precedence over anything else but bib), we insert it. Else, we don't insert it.
		#
		# TODO - handle the reason == 'man' cases...
		#

		# Get reason from most recent rights data:
		$ssth->execute($namespace, $barcode) || die("$thisprog -ERR- Database error: " . $dbh->errstr());

		my $hr = $ssth->fetchrow_hashref();

		my $most_recent_reason = $$hr{'name'} || undef;

		$ssth->finish();

		# Get attribute from most recent rights data:
		$asth->execute($namespace, $barcode) || die("$thisprog -ERR- Database error: " . $dbh->errstr());

		$hr = $asth->fetchrow_hashref();

		my $most_recent_attr = $$hr{'name'} || undef;

		$asth->finish();

		# Get source from most recent rights data:
		$source_sth->execute($namespace, $barcode) || die("$thisprog -ERR- Database error: " . $dbh->errstr());

		$hr = $source_sth->fetchrow_hashref();

		my $most_recent_source = $$hr{'name'} || undef;

		$source_sth->finish();


		my $do_insert = 0;

		# $most_recent_reason -> Most recent reason
		# $reason_name -> New reason
		if(defined $most_recent_reason && defined $most_recent_attr) {

			# If the new reason and attribute are the same as the most recent ones, ignore at this point. TODO in the future this assumption may not hold if we want to be able to update, say, the source or user
			if( ($reason_name eq $most_recent_reason) &&
			    ($attribute_name eq $most_recent_attr) ) {
				
				# Update if the source is different, but the attribute and reason are the same
				if(defined $source_name && $source_name ne $most_recent_source) {

					$do_insert = 1;
				}
				else {
					push @{$results{'already_in_db'}}, $barcode;

					next;
				}

			}

			else {

				if( $most_recent_reason eq 'bib' ) {
					# If the most recent reason is bib, then we can insert anything other than man, including bib
					if($reason_name ne 'man') {
						$do_insert = 1;
					}
					elsif($reason_name eq 'man' &&
						  $force_man) {
						$do_insert = 1;
					}
				}
				elsif( ($most_recent_reason ne 'bib') && ($most_recent_reason ne 'man') ) {
					# If the most recent reason is anything other than bib or man then we can insert anything other than bib or man
					if( ($reason_name ne 'bib') && ($reason_name ne 'man') ) {
						$do_insert = 1;
					}
				}
				elsif( $most_recent_reason eq 'man' ) {
					# TODO - add this functionality.
					# Skip for now
					$do_insert = 0;
				}
			}
		}
		else {
			# No rights in the db yet for this barcode so just insert whatever we have here
			$do_insert = 1;
		}

		# Insert new row with most recent rights data
		if( $do_insert ) {
			eval {
				$isth->execute($namespace, $barcode, $attribute, $reason, $source, $user, $note) or die("$thisprog -ERR- Database error: " . $dbh->errstr());
			};
			if($@) {
				warn($@);
			}
			else {
				push @{$results{'inserted'}}, $barcode;
				$queue_delete_sth->execute($namespace,$barcode);
			}
		}
		else {
			push @{$results{'skipped'}}, $barcode;
			$queue_delete_sth->execute($namespace,$barcode);
			next;
		}

	}

	close(IN);

	if($archive) {
		#
		# After populating rights database from *.rights file(s), move
		# file(s) to archive directory.
		#
	
		my $cmd = "mv $file $archive";

		if(my $res = `$cmd`) {
			die("Error moving rights file to archive: $res");
		}
	}
}

$isth->finish();

$dbh->disconnect();


#
# Print results
#
print "Results:\n";

print "  Rows inserted: " . @{$results{'inserted'}} . "\n" if(defined $results{'inserted'});
if(defined $results{'skipped'}) {
	print "  Barcodes skipped (manually set): " . @{$results{'skipped'}} . "\n";
	foreach (@{$results{'skipped'}}) {
		print "\t$_\n";
	}
}

if(defined $results{'already_in_db'}) {
	print "  Barcodes skipped (already in database with same attribute and reason): " . @{$results{'already_in_db'}} . "\n";

	foreach (@{$results{'already_in_db'}}) {
		print "\t$_\n";
	}
}

print "$thisprog -INFO- Done\n";
