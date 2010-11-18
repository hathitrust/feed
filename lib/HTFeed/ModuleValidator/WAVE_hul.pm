package HTFeed::ModuleValidator::WAVE_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

require HTFeed::QueryLib::WAVE_hul;
our $qlib = HTFeed::QueryLib::WAVE_hul->new();

=info
	WAVE-hul HTFeed validation plugin
=cut

sub _set_required_querylib {
	my $self = shift;
	$self->{qlib} = $qlib;
	return 1;
}

sub _set_validators {
	my $self = shift;
	$self->{validators} = {
		'codingHistory'		=> v_exists( 'wavMeta', 'codingHistory'),
		'description'		=> v_exists( 'waveMeta', 'description'),
		'audioDataEncoding'	=> v_exists( 'aes', 'audioDataEncoding'),
		'byteOrder'		=> v_exists( 'aes', 'byteOrder'),
		'numChannels'		=> v_exists( 'aes', 'numChannels'),
		'analogDigitalFlag'	=> v_exists( 'aes', 'analogDigitalFlag'),
		'bitDepth'		=> v_exists( 'aes', 'bitDepth'),
		'sampleRate'		=> v_exists( 'aes', 'sampleRate'),
		'useType'		=> v_exists( 'aes', 'useType'),
		'format' 		=> v_eq( 'repInfo', 'format', 'JPEG 2000' ),
		'status' 		=> v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),
		'module' 		=> v_eq( 'repInfo', 'module', 'JPEG2000-hul' ),
		'mime_type' 		=> v_and(
            		v_eq( 'repInfo', 'mimeType', 'image/jp2' ),
            		v_eq( 'mix',     'mime',     'image/jp2' )
        	),
		'profile1' 		=> v_or(
			v_eq( 'repInfo', 'profile1', 'Broadcast Wave Version 1' ),
			v_eq( 'repInfo', 'profile1', 'Broadcast Wave Version 2')
		),	
		'profile2' 		=> v_eq( 'repInfo', 'profile2', 'PCM Wave Format'),
		'originator' 		=> v_eq( 'wavMeta', 'originator', 'University of Michigan Library'),
		'checksumKind'		=> v_eq ('mets', 'checksumKind', 'MD5'),

		'originationDate'	=> v_exists( 'waveMeta', 'originationDate'),
    		#regex to validate originationDate
		#eg: ($date =~ m/^[0-9]{4}-(((0[13578]|(10|12))-(0[1-9]|[1-2][0-9]|3[0-1]))|(02-(0[1-9]|[1-2][0-9]))|((0[469]|11)-(0[1-9]|[1-2][0-9]|30)))$/)

		'mets' => sub {
			my $mets_mets = $self->_findeone("mets", "mets");
			my $mets_analogDigitalFlag = $self->_findone("mets", "analogDigitalFlag");
			my $mets_audioDataEncoding = $self->_findone("mets", "DataEncoding");
			my $mets_bitDepth = $self->_findone("mets", "bitDepth");
			my $mets_byteOrder = $self->_findone("mets", "byteOrder");
			my $mets_checksumCreateDate = $self->_findone("mets", "checksumCreateDate");
			my $mets_checksumKind = $self->_findone("mets", "checksumKind");
			my $mets_checksumValue = $self->_findone("mets", "checksumValue");
			my $mets_format = $self->_findone("mets", "format");
			my $mets_numChannels = $self->_findone("mets", "numChannels");
			my $mets_originatorReference = $self->_findone("mets", "originatorReference");
			my $mets_primaryIdentifier = $self->_findone("mets", "primaryIdentifier");
			my $mets_sampleRate = $self->_findone("mets", "sampleRate");
			my $mets_speedCoarse = $self->_findone("mets", "speedCoarse");
			my $mets_useType = $self->_findone("mets", "useType");


		};
	};
}

sub run {
	my $self = shift;

	# open contexts
	$self->_setcontext(
		name => "root",
		xpc => $self->{xpc}
	);
	$self->_openonecontext("repInfo");
	$self->_openonecontext("waveMeta");
	$self->_openonecontect("aes");
	
	# if we already have errors, quit now, we won't get anything else out of this without usable contexts
	if ($self->failed) {
	return;
	}

	# $self->_setup;
	if ($self->failed) {
	returns;
	}

	return $self->SUPER::run();
}

1;

__END__
