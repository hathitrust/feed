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
		'codingHistory'		=> v_exists( 'waveMeta', 'codingHistory'),
		'description'		=> v_exists( 'waveMeta', 'description'),
		'audioDataEncoding'	=> v_exists( 'aes', 'audioDataEncoding'),
		'byteOrder'			=> v_exists( 'aes', 'byteOrder'),
		'numChannels'		=> v_exists( 'aes', 'numChannels'),
		'analogDigitalFlag'	=> v_exists( 'aes', 'analogDigitalFlag'),
		'bitDepth'			=> v_exists( 'aes', 'bitDepth'),
		'useType'			=> v_exists( 'aes', 'useType'),
		'format' 			=> v_eq( 'repInfo', 'format', 'WAVE' ),
		'status' 			=> v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),
		'module' 			=> v_eq( 'repInfo', 'module', 'WAVE-hul' ),
		'mime_type' 		=> v_eq( 'repInfo', 'mimeType', 'audio/x-wave' ),
		'originator' 		=> v_eq( 'waveMeta', 'originator', 'University of Michigan Library'),
		'sampleRate'		=> v_exists( 'aes', 'sampleRate'),
		
		#TODO: define v_or for profile1a/b --> XPathValidator
		#also sample version does not contain values expected in spec
		#'profile1'	=> v_or(
			#	v_eq( 'repInfo', 'profile1', 'Broadcast Wave Version 1' ),
			#	v_eq( 'repInfo', 'profile1', 'Broadcast Wave Version 2' ),
		#),
		#'profile2' 			=> v_eq( 'repInfo', 'profile2', 'PCM Wave Format'),
		

		#TODO set date check
		#'originationDate'	=> v_exists( 'waveMeta', 'originationDate'),
    		#regex to validate originationDate
		#eg: ($date =~ m/^[0-9]{4}-(((0[13578]|(10|12))-(0[1-9]|[1-2][0-9]|3[0-1]))|(02-(0[1-9]|[1-2][0-9]))|((0[469]|11)-(0[1-9]|[1-2][0-9]|30)))$/)
	}
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
	$self->_openonecontext("aes");
	
	# if we already have errors, quit now, we won't get anything else out of this without usable contexts
	if ($self->failed) {
	return;
	}

	return $self->SUPER::run();
}

1;

__END__
