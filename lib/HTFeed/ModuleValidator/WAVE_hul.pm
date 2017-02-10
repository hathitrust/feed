package HTFeed::ModuleValidator::WAVE_hul;

use warnings;
use strict;

use HTFeed::ModuleValidator;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::ModuleValidator);

=head1 NAME

HTFeed::ModuleValidator::WAVE_hul

=head1 SYNOPSIS

	WAVE-hul HTFeed validation plugin

=cut

our $qlib = HTFeed::QueryLib::WAVE_hul->new();

sub _set_required_querylib {
    my $self = shift;
    $self->{qlib} = $qlib;
    return 1;
}

sub _set_validators {
    my $self = shift;
    $self->{validators} = {
        'format'    => { desc => 'Baseline WAVE format', detail => '', valid => v_eq( 'repInfo', 'format',   'WAVE' ) },
        'status'    => { desc => 'JHOVE status', detail => '', valid => v_eq( 'repInfo', 'status',   'Well-Formed and valid' ) },
        'module'    => { desc => 'JHOVE reporting module', detail => '', valid => v_eq( 'repInfo', 'module',   'WAVE-hul' ) },
        'mime_type' => { desc => 'MIME type', detail => '', valid => v_eq( 'repInfo', 'mimeType', 'audio/x-wave' ) },
        'profile1'  => { desc => 'WAVE profile', detail => '', valid => v_in( 'repInfo', 'profile1', ['PCMWAVEFORMAT','WAVEFORMATEX'] ) },
        'profile2'  => { desc => 'WAVE profile (broadcast wave)', detail => '', valid => v_in(
            'repInfo', 'profile2',
            [ 'Broadcast Wave Version 0', 'Broadcast Wave Version 1' ]
        ) },
        'codingHistory' => { desc => 'WAVE Coding History', detail => '', valid => v_exists( 'waveMeta', 'codingHistory' ) },
        'description'   => { desc => 'WAVE Description', detail => '', valid => v_exists( 'waveMeta', 'description' ) },
        'originator'    => { desc => 'WAVE originator', detail => '', valid => v_in(
            'waveMeta', 'originator',
            [ 'University of Michigan', 'University of Michigan Library', 'The MediaPreserve' ]
        ) },
        'originationDate' => { desc => 'WAVE origination date', detail => '', valid => sub {
            my $self = shift;
            my $date = $self->_findone( "waveMeta", "originationDate" );
            if ( $date =~
m!^(19|20)\d\d[: /.](0[1-9]|1[012])[: /.](0[1-9]|[12][0-9]|3[01])!
              )
            {
                $self->set_error(
                    "NotMatchedValue",
                    field  => 'originationDate',
                    actual => $date
                );
            }
        } },
        'sampleRate'        => { desc => 'AES sample rate', detail => '', valid => v_exists( 'aes', 'sampleRate' ) },
        'audioDataEncoding' => { desc => 'AES audio data encoding', detail => '', valid => v_exists( 'aes', 'audioDataEncoding' ) },
        'byteOrder'         => { desc => 'AES byte order', detail => '', valid => v_exists( 'aes', 'byteOrder' ) },
        'numChannels'       => { desc => 'AES number of channels', detail => '', valid => v_exists( 'aes', 'numChannels' ) },
        'analogDigitalFlag' => { desc => 'AES analog/digital flag', detail => '', valid => v_exists( 'aes', 'analogDigitalFlag' ) },
        'primaryID'         => { desc => 'AES primary ID', detail => '', valid => v_exists( 'aes', 'primaryID' ) },
        'bitDepth'          => { desc => 'AES bit depth', detail => '', valid => v_exists( 'aes', 'bitDepth' ) },
        'useType'           => { desc => 'AES use type', detail => '', valid => v_exists( 'aes', 'useType' ) },
    };
}

sub run {
    my $self = shift;

    # open contexts
    $self->_setcontext(
        name => "root",
        xpc  => $self->{xpc}
    );
    $self->_openonecontext("repInfo");
    $self->_openonecontext("waveMeta");
    $self->_openonecontext("aes");

# if we already have errors, quit now, we won't get anything else out of this without usable contexts
    if ( $self->failed ) {
        return;
    }

    return $self->SUPER::run();
}

package HTFeed::QueryLib::WAVE_hul;

# WAVE-hul HTFeed query plugin

use strict;
use base qw(HTFeed::QueryLib);

sub new {
    my $class = shift;

    # store all queries
    my $self = {
        contexts => {
            repInfo => {
                desc   => '',
                query  => "/jhove:jhove/jhove:repInfo",
                parent => "root"
            },
            waveMeta => {
                desc => '',
                query =>
"jhove:properties/jhove:property[jhove:name='WAVEMetadata']/jhove:values",
                parent => "repInfo"
            },
            aes => {
                desc  => '',
                query => 
"jhove:property[jhove:name='AESAudioMetadata']/jhove:values/jhove:value/aes:audioObject",
                parent => "waveMeta"
            },
        },

        queries => {

            # top level
            repInfo => {
                format =>
                  { desc => '', remediable => 0, query => "jhove:format" },
                status =>
                  { desc => '', remediable => 0, query => "jhove:status" },
                module => {
                    desc       => '',
                    remediable => 0,
                    query      => "jhove:sigMatch/jhove:module"
                },
                mimeType =>
                  { desc => '', remediable => 0, query => "jhove:mimeType" },
                profile1 => {
                    desc       => '',
                    remediable => 0,
                    query      => "jhove:profiles/jhove:profile[1]"
                },
                profile2 => {
                    desc       => '',
                    remediable => 0,
                    query      => "jhove:profiles/jhove:profile[2]"
                },
            },

            # waveMeta children
            waveMeta => {
                description => {
                    desc       => '',
                    remediable => 0,
                    query =>
"jhove:property/jhove:values/jhove:property[jhove:name='Description']"
                },
                originator => {
                    desc       => '',
                    remediable => 0,
                    query =>
"jhove:property/jhove:values/jhove:property[jhove:name='Originator']/jhove:values/jhove:value"
                },
                originationDate => {
                    desc       => '',
                    remediable => 0,
                    query =>
"jhove:property/jhove:values/jhove:property[jhove:name='OriginationDate']/jhove:values/jhove:value"
                },
                codingHistory => {
                    desc       => '',
                    remediable => 0,
                    query =>
"jhove:property/jhove:values/jhove:property[jhove:name='CodingHistory']"
                },

            },

            # aes children
            aes => {
                analogDigitalFlag => {
                    desc       => '',
                    remediable => 0,
                    query      => "\@analogDigitalFlag"
                },
                format =>
                  { desc => '', remediable => 0, query => "aes:format" },
                audioDataEncoding => {
                    desc       => '',
                    remediable => 0,
                    query      => "aes:audioDataEncoding"
                },
                useType =>
                  { desc => '', remediable => 0, query => "aes:use/\@useType" },
                primaryID => {
                    desc       => '',
                    remediable => 0,
                    query      => "aes:primaryIdentifier"
                },
                numChannels => {
                    desc       => '',
                    remediable => 0,
                    query      => "aes:face/aes:region/aes:numChannels"
                },
                bitDepth => {
                    desc       => '',
                    remediable => 0,
                    query      => "aes:formatList/aes:formatRegion/aes:bitDepth"
                },
                sampleRate => {
                    desc       => '',
                    remediable => 0,
                    query => "aes:formatList/aes:formatRegion/aes:sampleRate"
                },
                byteOrder =>
                  { desc => '', remediable => 0, query => "aes:byteOrder" },
              }

        },

    };
    bless( $self, $class );
    _compile $self;
    return $self;
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
