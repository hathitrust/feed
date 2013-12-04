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
        'format'    => v_eq( 'repInfo', 'format',   'WAVE' ),
        'status'    => v_eq( 'repInfo', 'status',   'Well-Formed and valid' ),
        'module'    => v_eq( 'repInfo', 'module',   'WAVE-hul' ),
        'mime_type' => v_eq( 'repInfo', 'mimeType', 'audio/x-wave' ),
        'profile1'  => v_eq( 'repInfo', 'profile1', 'PCMWAVEFORMAT' ),
        'profile2'  => v_in(
            'repInfo', 'profile2',
            [ 'Broadcast Wave Version 0', 'Broadcast Wave Version 1' ]
        ),
        'codingHistory' => v_exists( 'waveMeta', 'codingHistory' ),
        'description'   => v_exists( 'waveMeta', 'description' ),
        'originator'    => v_in(
            'waveMeta', 'originator',
            [ 'University of Michigan', 'University of Michigan Library' ]
        ),
        'originationDate' => sub {
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
        },
        'sampleRate'        => v_exists( 'aes', 'sampleRate' ),
        'audioDataEncoding' => v_exists( 'aes', 'audioDataEncoding' ),
        'byteOrder'         => v_exists( 'aes', 'byteOrder' ),
        'numChannels'       => v_exists( 'aes', 'numChannels' ),
        'analogDigitalFlag' => v_exists( 'aes', 'analogDigitalFlag' ),
        'primaryID'         => v_exists( 'aes', 'primaryID' ),
        'bitDepth'          => v_exists( 'aes', 'bitDepth' ),
        'useType'           => v_exists( 'aes', 'useType' ),
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
                query => query =>
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
"jhove:property/jhove:values/jhove:property[jhove:name='OriginationDate']"
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
