package HTFeed::VolumeValidator;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use HTFeed::ModuleValidator;
use List::MoreUtils qw(uniq);

use base qw(HTFeed::Stage);

our $logger = get_logger(__PACKAGE__);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages} = {
        file_names          => \&_validate_file_names,
        filegroups_nonempty => \&_validate_filegroups_nonempty,
        consistency         => \&_validate_consistency,
        checksums           => \&_validate_checksums,
        metadata            => \&_validate_metadata
    };

    $self->{run_stages} =
      [qw(file_names files_present consistency checksums metadata)];

    return $self;

}

sub run {
    my $self = shift;

    # Run each enabled stage
    foreach my $stage ( $self->{run_stages} ) {
        if ( exists( $self->{stages}{$stage} ) ) {
            my $sub = $self->{stages}{$stage};
            &{$sub}($self);
        }
        else {
            croak("Undefined validation stage $stage requested");
        }
    }

    # do this last
    $self->_set_done();

    return;
}

=item _validate_file_names

Ensures every file in the AIP staging directory is valid for the volume.

=cut

sub _validate_file_names {
    my $self   = shift;
    my $volume = $self->{volume};

    my $valid_file_pattern = $volume->get_valid_file_pattern();
    my @bad =
      grep( { !/$valid_file_pattern/ } $volume->all_directory_files() );

    if (@bad) {
        _set_error( 'Invalid file name(s):' . join( q{,}, @bad ) );

    }

    return;

}

=item _validate_filegroups_nonempty

Ensure that every listed filegroup (image, ocr, etc.) contains at least one file.

=cut

sub _validate_filegroups_nonempty {
    my $self   = shift;
    my $volume = $self->{volume};

    my $prev_filecount      = undef;
    my $prev_filegroup_name = q{};
    while ( my ( $filegroup_name, $filegroup ) =
        each( %{ $volume->get_file_groups() } ) )
    {
        my $filecount = scalar( @{$filegroup} );
        if ( !$filecount ) {
            _set_error("File group $filegroup is empty");
        }

        $prev_filegroup_name = $filegroup_name;
        $prev_filecount      = $filecount;

    }

    return;
}

=item _validate_consistency

Make sure every listed file in each file group (ocr, text, etc.) has a corresponding file in 
each other file group and that there are no sequence skips.

=cut

sub _validate_consistency {
    my $self   = shift;
    my $volume = $self->{volume};

    my $filegroups      = $volume->get_file_groups();
    my @filegroup_names = ();
    my %files           = ();

    # First determine what files belong to each sequence number
    while ( my ( $filegroup_name, $filegroup ) =
        each( %{ $volume->get_file_groups() } ) )
    {
        push( @filegroup_names, $filegroup_name );
        foreach my $file ( @{$filegroup} ) {
            if ( $file =~ /(\d+)\.(\w+)$/ ) {
                my $sequence_number = $1;
                $files{$sequence_number}{$filegroup_name} = $file;
            }
            else {
                _set_error(
"Can't extract sequence number from filename $file in group $filegroup_name"
                );
            }
        }
    }

    # Make sure there are no gaps in the sequence
    if ( !$volume->allow_sequence_gaps() ) {
        my $prev_sequence_number = 0;
        my @sequence_numbers     = sort( keys(%files) );
        foreach my $sequence_number (@sequence_numbers) {
            if ( $sequence_number > $prev_sequence_number + 1 ) {
                _set_error(
"Skip sequence number from $prev_sequence_number to $sequence_number"
                );
            }
            $prev_sequence_number = $sequence_number;
        }
    }

    # Make sure each filegroup has an object for each sequence number
    while ( my ( $sequence_number, $files ) = each(%files) ) {
        if ( @{$files} != @filegroup_names ) {
            _set_error(
                "File missing for $sequence_number: have "
                  . join( q{,}, @{$files} ),
                '; expected ' . join( q{,}, @filegroup_names )
            );
        }
    }

    return;

}

=item _validate_checksums

Validate each file against a precomputed list of checksums.

=cut

sub _validate_checksums {
    my $self      = shift;
    my $volume    = $self->{volume};
    my $checksums = $volume->get_checksum_cache();

   # make sure we check every file in the directory except for the checksum file
   # and make sure we check every file in the checksum file

    my @tovalidate = uniq(
        sort( $volume->all_directory_files() .
              keys( %{ $volume->get_checksum_cache() } ) ) );

    foreach my $file (@tovalidate) {
        my $expected = $checksums->{$file};
        if ( not defined $expected ) {
            _set_error("No checksum found for $file");
        }
        elsif ( md5sum($file) ne $expected ) {
            _set_error("Checksums check failed for $file");
        }

    }

    return;

}

=item _validate_metadata

Runs JHOVE on all the files for the given volume and validates their metadata.

=cut

sub _validate_metadata {
    my $self   = shift;
    my $volume = $self->{volume};

    my @files     = $volume->get_all_files;
    my $dir       = $volume->get_path;
    my $volume_id = $volume->get_objid;

    my $jhove_xml = _run_jhove($dir);

    # get xpc
    my $jhove_xpc;
    {
        my $jhove_parser = XML::LibXML->new();
        my $jhove_doc    = $jhove_parser->parse_string($jhove_xml);
        $jhove_xpc = XML::LibXML::XPathContext->new($jhove_doc);
    }

    # get repInfo nodes
    my $nodelist = $jhove_xpc->findnodes('//jhove:repInfo');

    # put repInfo nodes in a usable data structure
    my %nodes = ();
    while ( my $node = $nodelist->shift() ) {

        # get uri for this node
        my $fname = $jhove_xpc->findvalue( '@uri', $node );

        # remove leading whitespace
        $fname =~ s/^\s*//g;

        # populate hash
        $nodes{$fname} = $node;
    }

    foreach my $file (@files) {
        my $node;

        # get node for file
        if ( $node = $nodes{file} ) {

            # run module validator
            my $mod_val = HTFeed::ModuleValidator->new();
            $mod_val->run();

            # check, log success
            if ( $mod_val->succeeded() ) {
                $logger->debug("$file in $volume_id ok");
            }
            else {
                _set_error("$file bad");
            }
        }
        else {
            _set_error("$file missing");
        }
    }

    return;

}

# run jhove
sub _run_jhove {
    my $dir = shift;
    my $xml = `jhove -h XML -c /l/local/jhove-1.5/conf/jhove.conf $dir`;

    return $xml;
}

1;

__END__;
