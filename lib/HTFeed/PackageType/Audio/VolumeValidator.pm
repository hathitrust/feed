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

	my $source_analogDigitalFlag = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/\@analogDigitalFlag");

	#techMD tests
	foreach my $techmd_node ($xpc->findnodes("//mets:techMD")){

        my $techmd_id = $techmd_node->getAttribute("ID");
		my $file = $xpc->findvalue("//mets:file[\@ADMID='$techmd_id']/mets:FLocat/\@xlink:href");
		if(! -e $volume->get_staging_directory() . "/" . $file) {
			$self->set_error("MissingFile", field => 'file');
		}

		my $checksumValue = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumValue", $techmd_node);
		if(! $checksumValue) {
			$self->set_error("MissingField", field=>'checksumValue');
		}
		my $checksumKind = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumKind", $techmd_node);
		if(! $checksumKind) {
			$self->set_error("MissingField", field=>'checksumKind');
		}
		if ($checksumKind ne "MD5") {
			$self->set_error("BadValue", field => 'checksumKind', expected => 'MD5', actual => $checksumKind);
		}
		my $checksumCreateDate = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:checksum/aes:checksumCreateDate", $techmd_node);
		if(! $checksumCreateDate) {
			$self->set_error("MissingField", field =>'checksumCreateDate');
		}

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

        my $audioDataEncoding = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:audioDataEncoding",$techmd_node);
		if (! $audioDataEncoding) {
            $self->set_error("MissingField", field=>'audioDataEncoding');
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
	
    my $source_format = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/aes:format");
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
