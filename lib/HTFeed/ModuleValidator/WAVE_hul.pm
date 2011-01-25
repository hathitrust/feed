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
		'format' 			=> v_eq( 'repInfo', 'format', 'WAVE' ),
		'status' 			=> v_eq( 'repInfo', 'status', 'Well-Formed and valid' ),
		'module' 			=> v_eq( 'repInfo', 'module', 'WAVE-hul' ),
		'mime_type' 		=> v_eq( 'repInfo', 'mimeType', 'audio/x-wave' ),
		'profile1' 			=> v_eq( 'repInfo', 'profile1', 'PCMWAVEFORMAT'),
		'profile2'			=> v_in( 'repInfo', 'profile2', ['Broadcast Wave Version 1', 'Broadcast Wave Version 2'] ),
		'codingHistory'		=> v_exists( 'waveMeta', 'codingHistory'),
		'description'		=> v_exists( 'waveMeta', 'description'),
		'originator' 		=> v_eq( 'waveMeta', 'originator', 'University of Michigan Library'),
		'originationDate'	=> sub{
			my $self = shift;
			my $date = $self->_findone( "waveMeta", "originationDate" );
			if ($date =~ m!^(19|20)\d\d[: /.](0[1-9]|1[012])[: /.](0[1-9]|[12][0-9]|3[01])!) {
				$self->set_error(
					"NotMatchedValue",
					field => 'originationDate',
					actual => $date
				);
			}
		},
		'sampleRate'		=> v_exists( 'aes', 'sampleRate'),
		'audioDataEncoding'	=> v_exists( 'aes', 'audioDataEncoding'),
		'byteOrder'			=> v_exists( 'aes', 'byteOrder'),
		'numChannels'		=> v_exists( 'aes', 'numChannels'),
		'analogDigitalFlag'	=> v_exists( 'aes', 'analogDigitalFlag'),
		'bitDepth'			=> v_exists( 'aes', 'bitDepth'),
		'useType'			=> v_exists( 'aes', 'useType'),
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
