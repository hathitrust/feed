#!/usr/bin/perl

package HTFeed::PackageType::Audio::VolumeValidator;

use strict;
use base qw(HTFeed::VolumeValidator);
use HTFeed::PackageType::Audio::Volume;
use List::MoreUtils qw(uniq);
use Carp;
use Digest::MD5;
use HTFeed::Config qw(get_config);
use Log::Log4perl qw(get_logger);

my $logger = get_logger(__PACKAGE__);

=item _validate_mets_consistency

test special logic for audio METS validation

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
	$self->{stages}{validate_mets_consistency} = \&_validate_mets_consistency;
	$self->{stages}{validate_wave_checksums} = \&_validate_wave_checksums;
	$self->{stages}{validate_jp2} = \&_validate_jp2;
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
			unless ($tech_sampleRate == 96000) {
				$self->set_error("BadValue",field=>'sampleRate',expected=>96000,actual=>$tech_sampleRate);
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


=item _validate_mets_checksums

validate checksums for wave files only
based on checksum value in mets file

=cut

sub _validate_wave_checksums {

	my $self = shift;
	my $volume = $self->{volume};
	my $path = $volume->get_staging_directory();
	my $checksums = $volume->get_checksums();

	my @tovalidate = uniq(
		sort( (
			@{ $volume->get_jhove_files() },
			keys( %{ $volume->get_checksums() } )
		) )
	);

	my @bad_files = ();

	foreach my $file (@tovalidate) {
		next unless ($file =~ /[ap]m\d{2,8}.(wav)/);
		my $expected = $checksums->{$file};
		my $actual =md5sum("$path/$file");

		if ($actual ne $expected ) {
			$self->set_error(
				"BadChecksum",
				field => 'checksum',
				file => $file,
				expected => $expected,
				actual => $actual
			);
			push( @bad_files, "$file" );
		}
	}

	my $outcome;
	if (@bad_files) {
		$outcome = PREMIS::Outcome->new('warning');
		$outcome->add_file_list_detail( "files failed checksum validation",
			"failed", \@bad_files );
	}
	else {
		$outcome = PREMIS::Outcome->new('pass');
	}
	$volume->record_premis_event( 'page_md5_fixity', outcome => $outcome );

	return;

}

sub md5sum {
	my $file = shift;

	my $ctx = Digest::MD5->new();
	my $fh;
	open( $fh, "<", $file ) or croak("Can't open $file: $!");
	$ctx->addfile($fh);
	close($fh);
	return $ctx->hexdigest();
}

sub _validate_jp2 {

    my $self = shift;
	my $path = shift;
    my $volume = $self->{volume};

    my @tovalidate = uniq(
        sort( (
            @{ $volume->get_jhove_files() },
            keys( %{ $volume->get_checksums() } )
        ) )
    );

    foreach my $file (@tovalidate) {
		next unless ($file =~ /\w+\.(jp2)/);

		my $dir = $volume->get_staging_directory();
    	my $files_for_cmd = join( ' ', map { "$dir/$_" } $file );
    	my $jhove_path = get_config('jhove');
    	my $jhove_conf = get_config('jhoveconf');
    	my $jhove_cmd = "$jhove_path -h XML -c $jhove_conf -m JPEG2000-hul " . $files_for_cmd;

		my @result_lines = split("\n", `$jhove_cmd`);

		foreach my $line (@result_lines) {
			next unless ($line =~/status/);
			my $expected = "Well-Formed and valid";
			if($line !~ /$expected/i) {
				$self->set_error(
					"BadFile",
                	file => $file,
                	expected => $expected,
                	actual => $line
            );

			} else {
				return;
			}
		}
	}
}
1;
