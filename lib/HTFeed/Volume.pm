package HTFeed::Volume;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use HTFeed::XMLNamespaces qw(register_namespaces);
use HTFeed::Namespace;
use XML::LibXML;
use GROOVE::Book;
use Carp;

our $logger = get_logger(__PACKAGE__);

sub new {
    my $class = shift;

    my $self = {
        objid     => undef,
        namespace => undef,
        packagetype => undef,
        @_,

        #		files			=> [],
        #		dir			=> undef,
        #		mets_name		=> undef,
        #		mets_xml		=> undef,
    };

    $self->{groove_book} =
      GROOVE::Book->new( $self->{objid}, $self->{namespace},
        $self->{packagetype} );

    $self->{nspkg} = new HTFeed::Namespace($self->{namespace},$self->{packagetype});

    $self->{nspkg}->validate_barcode($self->{objid}) 
	or croak("Invalid barcode $self->{objid} provided for $self->{namespace}");

    bless( $self, $class );
    return $self;
}

=item get_identifier

Returns the full identifier (namespace.objid) for the volume

=cut

sub get_identifier {
    my $self = shift;
    return $self->get_namespace() . q{.} . $self->get_objid();

}

=item get_namespace

Returns the namespace identifier for the volume

=cut

sub get_namespace {
    my $self = shift;
    return $self->{namespace};
}

=item get_objid

Returns the ID (without namespace) of the volume.

=cut

sub get_objid {
    my $self = shift;
    return $self->{objid};
}


=item get_file_groups 

Returns a hash of lists containing the logical groups of files within the volume.

For example:

{ 
  ocr => [0001.txt, 0002.txt, ...]
  image => [0001.tif, 0002.jp2, ...]
}

=cut

sub get_file_groups {
    my $self = shift;

    my $book = $self->{groove_book};

    my $filegroups = {};
    $filegroups->{image} = $book->get_all_images();
    $filegroups->{ocr}   = $book->get_all_ocr();
    $filegroups->{hocr} = $book->get_all_hocr() if $book->hocr_files_used();

    return $filegroups;
}

=item get_all_directory_files

Returns a list of all files in the staging directory for the volume's AIP

=cut

sub get_all_directory_files {
    my $self = shift;

    return $self->{groove_book}->get_all_files();
}

=item get_staging_directory

Returns the staging directory for the volume's AIP

=cut

sub get_staging_directory {
    my $self = shift;
    return $self->{groove_book}->get_path();
}

=item get_all_content_files

Returns a list of all files that will be validated.

=cut

sub get_all_content_files {
    my $self = shift;
    my $book = $self->{groove_book};

    return [( @{ $book->get_all_images() }, @{ $book->get_all_ocr() },
        @{ $book->get_all_hocr() })];
}

=item get_checksums

Returns a hash of precomputed checksums for files in the package's AIP where
the keys are the filenames and the values are the MD5 checksums.

=cut

sub get_checksums {
    my $self = shift;

    if ( !defined $self->{checksums} ) {
        my $checksums = {};

        my $path = $self->get_staging_directory();
        my $checksum_file = $self->{groove_book}->get_checksum_file();
        if ( defined $checksum_file ) {
            my $checksum_fh;
            open( $checksum_fh, "<", "$path/$checksum_file" )
              or croak("Can't open $checksum_file: $!");
            while ( my $line = <$checksum_fh> ) {
                chomp $line;
                my ( $checksum, $filename ) = split( /\s+/, $line );
                $checksums->{$filename} = $checksum;
            }
            close($checksum_fh);
        }
        else {

            # try to extract from source METS
            my $xpc = $self->get_source_mets_xpc();
            foreach my $node ( $xpc->findnodes('//mets:file') ) {
                my $checksum = $xpc->findvalue( './@CHECKSUM', $node );
                my $filename =
                  $xpc->findvalue( './mets:FLocat/@xlink:href', $node );
                $checksums->{$filename} = $checksum;
            }
        }
        $self->{checksums} = $checksums;
    }

    return $self->{checksums};
}

=item get_checksum_file

Returns the name of the file containing the checksums. Useful since that file won't have
a checksum computed for it.

=cut

sub get_checksum_file {
    my $self          = shift;
    my $checksum_file = $self->{groove_book}->get_checksum_file();
    $checksum_file = $self->{groove_book}->get_source_mets_file()
      if not defined $checksum_file;
    return $checksum_file;
}

=item get_source_mets_file

Returns the name of the source METS file

=cut

sub get_source_mets_file {
    my $self = shift;
    return $self->{groove_book}->get_source_mets_file();
}

=item get_source_mets_xpc

Returns an XML::LibXML::XPathContext with the following namespace set:

and the context node positioned at the document root of the source METS.

=cut

sub get_source_mets_xpc {
    my $self = shift;

    my $mets = $self->get_source_mets_file();
    my $path = $self->get_staging_directory();
    my $xpc;

    eval {
        my $parser = XML::LibXML->new();
        my $doc    = $parser->parse_file("$path/$mets");
        $xpc = XML::LibXML::XPathContext->new($doc);
        register_namespaces($xpc);
    };

    if ($@) {
        croak("-ERR- Could not read XML file $mets: $@");
    }
    return $xpc;

}

=item get_nspkg

Returns the HTFeed::Namespace object that provides namespace & package type-
specific configuration information.

=cut

sub get_nspkg{
    my $self = shift;
    return $self->{nspkg};
}

=item get_metadata_files

Get all files that will need to have their metadata validated with JHOVE

=cut

sub get_metadata_files {
    my $self = shift;
    my $book = $self->{groove_book};
    return $book->get_all_images();
}

=item get_utf8_files

Get all files that should be valid UTF-8

=cut

sub get_utf8_files {
    my $self = shift;
    my $book = $self->{groove_book};
    return [( @{ $book->get_all_ocr() }, @{ $book->get_all_hocr() })]; 
}


1;

__END__;
