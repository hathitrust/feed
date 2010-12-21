#!/usr/bin/perl

use strict;
use warnings;
use Archive::Extract;
use DBI;
use File::Fetch;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools qw(get_dbh);

my $dbh = get_dbh();

#Working assumption: update HT Files on first of the month only, can modify this as needed
my $mo;
my($today, $mth, $annum)=(localtime)[3,4,5];
my $date = "$today-".($mth+1)."-".($annum+1900)."\n";

# Is it the first of the month? If so, get updated info
if($today != 1) {
	die ("No new records\n");
	exit 0;
}

my $month= (localtime)[4];
my $year = (localtime)[5];
my $yr = $year+1900;
my $day = "01";

if ($month > 8) {
	$mo = $month+1;
} else {
	$mo = 0 . $month+1;
}

my $dFile= "hathi_full_$yr$mo$day.txt";
my $temp_dir="/htapps/ezbrooks.babel/git/feed/bin/audit"; #change if needed
my $file = "$dFile" . ".gz";
my $hathiTemp = "hathi_full_temp.txt";

my $fetch = File::Fetch->new(uri => "http://www.hathitrust.org/sites/www.hathitrust.org/files/hathifiles/$file");
my $dest = $fetch->fetch(to => $temp_dir) or die $fetch->error;

my $extract = Archive::Extract->new(archive => "$file");
my $unzip = $extract->extract(to => $temp_dir) or die $extract->error;

# remove tar.gz version
my $remove = "$temp_dir/$file";
unlink $remove;

# adjust ht_file to work with db
my $final = "$temp_dir/$dFile";
my $update = "$temp_dir/$hathiTemp";
open(INFILE, "<$final") or die("Couldn't open file $final");
open(OUTFILE, ">$update") or die("Couldn't open file $update");
my $line;
while ($line = <INFILE>) {
	chomp($line);
	my @fields = split ("/\t/", $line);
	map {s/(\w+).(\d+)/$1\t$2/} @fields;
	print OUTFILE join("\t",@fields), "\n";
}
close(INFILE);
close(OUTFILE);

# remove original
unlink $final;

# rename update with original name
rename $update, $dFile;

# insert updated data to table
my $insert="load data local infile '$final' replace into table ht_files;";
my $handle=$dbh->prepare($insert);
$handle->execute;
# if error {
	# warn . . .
#}

# Compare HTFiles and right_current

#In ht_files but not in rights_current
my $first="select * from ht_files where ht_files.id not in (select mdp.rights_current.id from mdp.rights_current where ht_files.id=mdp.rights_current.id);";
my $sth = $dbh->prepare($first);
$sth->execute();
#TODO:
# pipe output . . . to file?
# warn on error . . .


#in rights_current but not in ht_files
my $second="select * from mdp.rights_current where mdp.rights_current.id not in (select ht_files.id from ht_files where mdp.rights_current.id=ht_files.id);";
my $sth2 = $dbh->prepare($second);
$sth2->execute;
#TODO:
# pipe output . . . to file?
# warn on error . . .

__END__
