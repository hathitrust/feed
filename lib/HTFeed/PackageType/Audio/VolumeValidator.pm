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

    # get top-level xpathcontext for METS
    my $xpc = $volume->get_source_mets_xpc();

	#definitions for comparison tests
	my $source_analogDigitalFlag = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/\@analogDigitalFlag");
    my $source_format = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/aes:format");
	my $source_bitDepth = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:formatList/aes:formatRegion/aes:bitDepth");
	my $source_sampleRate = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:formatList/aes:formatRegion/aes:sampleRate");

	#techMD tests
	foreach my $techmd_node ($xpc->findnodes("//mets:techMD")){

        my $techmd_id = $techmd_node->getAttribute("ID");
		my $file = $xpc->findvalue("//mets:file[\@ADMID='$techmd_id']/mets:FLocat/\@xlink:href");
		if(! -e $volume->get_staging_directory() . "/" . $file) {
			$self->set_error("MissingFile", field => 'file');
		}

		#tests for existence of values
		my $checksumValue = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumValue", $techmd_node);
		if(! $checksumValue) {
			$self->set_error("MissingField", field=>'checksumValue');
		}

		my $checksumKind = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumKind", $techmd_node);
		if(! $checksumKind) {
			$self->set_error("MissingField", field=>'checksumKind');
		}

		my $checksumCreateDate = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumCreateDate", $techmd_node);
		if(! $checksumCreateDate) {
			$self->set_error("MissingField", field =>'checksumCreateDate');
		}

        my $audioDataEncoding = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:audioDataEncoding",$techmd_node);
		if (! $audioDataEncoding) {
            $self->set_error("MissingField", field=>'audioDataEncoding');
        }
	
		my $tech_bitDepth = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:formatList/aes:formatRegion/aes:bitDepth",$techmd_node);
		if (! $tech_bitDepth) {
			$self->set_error("MissingField", field=>'bitDepth');
		}

		my $tech_sampleRate = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:formatList/aes:formatRegion/aes:sampleRate",$techmd_node);
		if (! $tech_sampleRate) {
			$self->set_error("MissingField", field=>'sampleRate');
		}

		# test for useType & primaryID
		my $tech_primaryID = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:primaryIdentifier[\@identifierType='FILE_NAME']",$techmd_node);
		my $tech_useType = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType",$techmd_node);
		if ($tech_primaryID =~ /^am/) {
			if ($tech_useType ne "PRESERVATION_MASTER") {
				$self->set_error("BadValue",field => 'aes:useType',expected => "PRESERVATION_MASTER",actual=>$tech_useType);
			}
		} elsif ($tech_primaryID =~ /^pm/) {
			if ($tech_useType ne "PRODUCTION_MASTER") {
				$self->set_error("BadValue",field => 'aes:useType',expected => "PRODUCTION_MASTER",actual=>$tech_useType);
			}
		} else {
            $self->set_error("BadValue",field=>'aes:primaryIdentifier',expected=>'am,pm',actual=>$tech_primaryID);
        }

		#test for checksumKind
		if ($checksumKind ne "MD5") {
			$self->set_error("BadValue", field => 'checksumKind', expected => 'MD5', actual => $checksumKind);
		}

		#test for bitDepth & sampleRate
		if ($source_format eq "DAT" || $source_format eq "CD") {
			if ($tech_bitDepth ne $source_bitDepth) {
				$self->set_error("BadValue",field=>'bitDepth',expected=>$source_bitDepth,actual=>$tech_bitDepth);
			}
			if ($tech_sampleRate ne $source_sampleRate) {
				$self->set_error("BadValue",field=>'sampleRate',expected=>$source_sampleRate,actual=>$tech_sampleRate);
			}
		} else {
			if ($tech_bitDepth ne "24") {
				$self->set_error("BadValue",field=>'bitDepth',expected=>'24',actual=>$tech_bitDepth);
			}
			if ($tech_sampleRate ne "96000") {
				$self->set_error("BadValue",field=>'sampleRate',expected=>'96000',actual=>$tech_sampleRate);
			}
		}
		
        	
	}

	#sourceMD tests
    my $source_UseType = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType");
	if($source_UseType ne "ORIGINAL_MASTER") {
    	$self->set_error("BadValue",field=>'source useType',actual=>$source_UseType,expected=>"ORIGINAL_MASTER");
	}

	my $speedCoarse = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:formatList/aes:formatRegion/aes:speed/aes:speedCoarse");
	if ($speedCoarse eq '')  {
		$self->set_error("MissingField", field =>'speedCoarse');
	}
	
	if ($source_format eq "DAT" || $source_format eq "CD") {
 		if ($source_analogDigitalFlag ne "PHYS_DIGITAL") {
			$self->set_error("BadValue",field=>'analogDigitalFlag',expected=>'PHYS_DIGITAL',actual=>$source_analogDigitalFlag);
		}
	} elsif ($source_analogDigitalFlag ne "ANALOG") {
		$self->set_error("BadValue",field=>'analogDigitalFlag',expected=>'ANALOG',actual=>$source_analogDigitalFlag);
	}

    return;
}

1;
