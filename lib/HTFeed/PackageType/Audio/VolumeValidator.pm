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

	foreach my $techmd_node ($xpc->findnodes("//mets:techMD")) {
        my $techmd_id = $techmd_node->getAttribute("ID");
		my $file = $xpc->findvalue("//mets:file[\@ADMID='$techmd_id']/mets:FLocat/\@xlink:href");
		if(! -e $volume->get_staging_directory() . "/" . $file) {
			$self->set_error("MissingFile", field => 'file');
		}

		#useType
		my $primaryIdentifier = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:primaryIdentifier[\@identifierType='FILE_NAME']",$techmd_node);
		my $useType = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType",$techmd_node);
		if ($primaryIdentifier =~ /^am/) {
			if ($useType ne "PRESERVATION_MASTER") {
				$self->set_error("BadValue",field => 'aes:useType',expected => "PRESERVATION_MASTER",actual=>$useType);
			}
		} elsif ($primaryIdentifier =~ /^pm/) {
			if ($useType ne "PRODUCTION_MASTER") {
				$self->set_error("BadValue",field => 'aes:useType',expected => "PRODUCTION_MASTER",actual=>$useType);
			}
		} else {
            $self->set_error("BadValue",field=>'aes:primaryIdentifier',expected=>'am,pm',actual=>$primaryIdentifier);
        }

        # techMD section cross-checks
		#TODO: same checks, different xpaths --> shorten code here?
        my $audioDataEncoding = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:audioDataEncoding",$techmd_node);
		if (! $audioDataEncoding) {
            $self->set_error("MissingField", field=>'audioDataEncoding');
        }

		my $byteOrder = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:byteOrder",$techmd_node);
			if(! $byteOrder) {
			$self->set_error("MissingField", field=>'byteOrder');
		}
        	
		my $numChannels = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:face/aes:region/aes:numChannels",$techmd_node);
		if(! $numChannels) {
			$self->set_error("MissingField", field=>'numChannels');
		}

		my $format = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/aes:format",$techmd_node);
		if(! $format) {
			$self->set_error("MissingField", field=>'format');
		}

		my $analogDigitalFlag = $xpc->findvalue("./mets:mdWrap/mets:xmlData/aes:audioObject/\@analogDigitalFlag",$techmd_node);
		if(! $analogDigitalFlag) {
			$self->set_error("MissingField", field=>'analogDigitalFlag');
		}
	}

	#sourceMD
    my $sourceUseType = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/\@useType");
	if($sourceUseType ne "ORIGINAL_MASTER") {
    	$self->set_error("BadValue",field=>'source useType',actual=>$sourceUseType,expected=>"ORIGINAL_MASTER");
	}
    		
    my $sourceFormat = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/aes:use/aes:format");
	my $analogDigitalFlag = $xpc->findvalue("//mets:sourceMD/mets:mdWrap/mets:xmlData/aes:audioObject/\@analogDigitalFlag");
	if ($sourceFormat eq "DAT" || $sourceFormat eq "CD") {
 		if ($analogDigitalFlag ne "PHYS_DIGITAL") {
			$self->set_error("BadValue",field=>'analogDigitalFlag',expected=>'PHYS_DIGITAL',actual=>$analogDigitalFlag);
		}
	} elsif ($analogDigitalFlag ne "ANALOG") {
		$self->set_error("BadValue",field=>'analogDigitalFlag',expected=>'ANALOG',actual=>$analogDigitalFlag);
	}
    return;
}

1;
