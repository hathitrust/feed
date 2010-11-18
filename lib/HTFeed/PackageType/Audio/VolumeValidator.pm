#!/usr/bin/perl

use strict;
use base qw('HTFeed::VolumeValidator');

=item _validate_mets_consistency

test special logic for audio METS validation

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
	$self->{stages}{validate_mets_consistency} = \&_validate_mets_consistency;
	return $self;
}

sub _validate_mets_consistency {
    my $self = shift;
    my $volume = $self->{volume};
    $self->SUPER::_validate_mets_consistency();

    # get top-level xpathcontext for METS
    my $xpc = $volume->get_source_mets_xpc();

	my $sourceMD = ;

    foreach my $techmd_id ($xpc->findnodes('//mets:techMD/@ID')) {
        my $file = $xpc->findnodes("//mets:file[\@ADMID=$techmd_id]");
        if(! -e $file) {
		#$self->set_error("METS file not found",...);
	}

        #bitDepth & sampleRate
		my $techBitDepth = $xpc->findnodes("//");
		my $techSampleRate = $xpc->findnodes("//");
		my $sourceFormat = (); #sourceMD format
		my $sourceBitDepth = (); #sourceMD bitDepth
		my $sourceSampleRate = (); #sourceMD sampleRate
		if ($sourceFormat eq "CD" || $sourceFormat eq "DAT") {
			if ($techBitdepth ne $sourceBitDepth) {
				if ($techBitDepth != 24) {
					#$self->set_error("");
				}
			} elsif ($techSampleRate ne $sourceSampleRate) {
				if ($techSampleRate != 96000) {
					#$self->set_error("");
				}
			}
		}	

        #useType
		my $primaryIdentifier = $xpc->findnodes("//");
		my $useType = $xpc->findnodes("//");
		if ($primaryIdentifier eq "am") {
			if ($useType ne "PRESERVATION_MASTER") {
				#self->set_error(...value must equal PRESERVATION_MASTER)
			}
		} elsif ($primaryIdentifier eq "pm") {
			if ($useType ne "PRODUCTION_MASTER" {
				#$self->set_error(...value must equal PRODUCTION_MASTER)
		} else {
			#$self->set_error(... $primaryIdentifier must be "am" or "pm")
		}

        # techMD section cross-checks    
        my $audioDataEncoding = $xpc->findnodes("//");
        my $byteOrder = $xpc->findnodes("//");
        my $numChannels = $xpc->findnodes("//");
        my $format = $xpc->findnones("//");
        my $analogDigitalFlag = $xpc->findnodes("//");
            
    }

    my $sourceUseType = $xpc->findnodes('//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/@useType');
	if(! -e $sourceUseType) {
		#$self->set_error(value doesn't exist)
	} elsif($sourceUseType ne "ORIGINAL_MASTER") {
    	#$self->set_error(must equal "ORIGINAL_MASTER")
	}
    
    my $sourceFormat = (); #sourceMD/aes:format
    my $analogDigitalFlag = (); #mets:sourcemd/aes:audioObject/analogDigitalFlag=""
    if ($sourceFormat eq "DAT" || $sourceFormat eq "CD") {
        if ($analogDigitalFlag ne "PHYS_DIGITAL") {
			#$self->set_error(wrong values)
		}
	} elsif ($analogDigitalFlag ne "ANALOG") {
		#$self->set_error(wrong values)
	}

    return;
}

1;
