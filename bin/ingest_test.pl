#!/usr/bin/perl

use warnings;
use strict;
use HTFeed::Volume;
use HTFeed::VolumeValidator;
use HTFeed::Log;

use HTFeed::PackageType::Google::Download;
use HTFeed::PackageType::Google::Unpack;

HTFeed::Log->init();

# autoflush STDOUT
$| = 1;

# check for legacy environment vars
unless (defined $ENV{GROOVE_WORKING_DIRECTORY} and defined $ENV{GROOVE_CONFIG}){
    print "GROOVE_WORKING_DIRECTORY and GROOVE_CONFIG must be set\n";
    exit 0;
}

# read args
my $packagetype = shift;
my $namespace = shift;
my $objid = shift;

unless ($objid and $namespace and $packagetype){
    print "usage: vt packagetype namespace objid\n";
    exit 0;
}

print sprintf("Test ingest of %s %s %s commencing...\n",$packagetype,$namespace,$objid);

# make Volume object
print 'Instantiating Volume object...';
my $volume = HTFeed::Volume->new(objid => $objid,namespace => $namespace,packagetype => $packagetype);
print "success\n";

my $stage;

# Download
print 'Downloading...';
$stage = HTFeed::PackageType::Google::Download->new(volume => $volume);
$stage->run();
if ($stage->succeeded()){
    print "success\n";
}
else{
    print "failure\n";
}

# Unpack
print 'Unpacking...';
$stage = HTFeed::PackageType::Google::Unpack->new(volume => $volume);
$stage->run();
if ($stage->succeeded()){
    print "success\n";
}
else{
    print "failure\n";
}


__END__
# Validation
print 'Validating...';

# Pack
print 'Packing...';

# Mets
print "Metsing...not implimented\n";

# Collate
print "Collating...not implimented\n"