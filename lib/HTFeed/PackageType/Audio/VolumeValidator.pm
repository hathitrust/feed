#!/usr/bin/perl

package HTFeed::PackageType::Audio::VolumeValidator;

use strict;
use base qw(HTFeed::VolumeValidator);

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

	my $sourceMD = $xpc->findnodes("//mets:sourceMD");

	foreach my $techmd_id ($xpc->findnodes("//mets:techMD/\@ID")) {
		my $file = $xpc->findnodes("//mets:file[\@ADMID=$techmd_id]");
		if(! -e $file) {
			$self->set_error("MissingFile", field => 'file');
		}

		#useType
		my $primaryIdentifier = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:primaryIdentifier/\@identifierType");
		my $useType = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType");
		if ($primaryIdentifier eq "am") {
			if ($useType ne "PRESERVATION_MASTER") {
				$self->set_error("BadValue");
			}
		} elsif ($primaryIdentifier eq "pm") {
			if ($useType ne "PRODUCTION_MASTER") {
				$self->set_error("BadValue");
			}
		} else {
				$self->set_error("BadValue");
			}

        # techMD section cross-checks    
        my $audioDataEncoding = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:audioDataEncoding");
        my $byteOrder = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:byteOrder");
        my $numChannels = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:face/aes:region/aes:numChannels");
        my $format = $xpc->findnones("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:format");
        my $analogDigitalFlag = $xpc->findnodes("//mets:techMD/mets:mdWrap/mets:xmlData/aes:audioObject/\@analogDigitalFlag");
	}

    my $sourceUseType = $xpc->findnodes("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType");
	if(! -e $sourceUseType) {
		$self->set_error("MissingField");
	} elsif($sourceUseType ne "ORIGINAL_MASTER") {
    		$self->set_error("BadValue");
	}
    
    my $sourceFormat = (); #sourceMD/aes:format
    my $analogDigitalFlag = $xpc->findnodes("//mets:sourcemd/aes:audioObject/\@DigitalFlag");
    if ($sourceFormat eq "DAT" || $sourceFormat eq "CD") {
        if ($analogDigitalFlag ne "PHYS_DIGITAL") {
			$self->set_error("BadValue");
		}
	} elsif ($analogDigitalFlag ne "ANALOG") {
		$self->set_error("BadValue");
	}

    return;
}

1;
