package HTFeed::VolumeValidator;

use warnings;
use strict;
use Log::Log4perl qw(get_logger);
use XML::LibXML;
use HTFeed::ModuleValidator;
use List::MoreUtils qw(uniq);
use Carp;
use Digest::MD5;
use Encode;
use HTFeed::XMLNamespaces qw(register_namespaces);

use base qw(HTFeed::Stage);

our $logger = get_logger(__PACKAGE__);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages} = {
        validate_file_names          => \&_validate_file_names,
        validate_filegroups_nonempty => \&_validate_filegroups_nonempty,
        validate_consistency         => \&_validate_consistency,
        validate_checksums           => \&_validate_checksums,
	validate_utf8		     => \&_validate_utf8,
        validate_metadata            => \&_validate_metadata
    };

    $self->{run_stages} = [
        qw(validate_file_names
          validate_filegroups_nonempty
          validate_consistency
          validate_checksums
	  validate_utf8
          validate_metadata)
    ];

    return $self;

}

sub run {
    my $self = shift;

    # Run each enabled stage
    foreach my $stage ( @{$self->{run_stages}} ) {
        if ( exists( $self->{stages}{$stage} ) ) {
            my $sub = $self->{stages}{$stage};
            $logger->debug("Running validation stage $stage");
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

    my $valid_file_pattern = $volume->get_nspkg()->get('valid_file_pattern');
    my @bad =
      grep( { !/$valid_file_pattern/ } @{ $volume->get_all_directory_files() } );

    if (@bad) {
       $self->_set_error( 'Invalid file name(s):' . join( q{,}, @bad ) );

    }

    return;

}

=item _validate_filegroups_nonempty

Ensure that every listed filegroup (image, ocr, etc.) contains at least one file.

TODO: Use required filegroups from ns/packagetype config
TODO: Use filegroup patterns from ns/packagetype config to populate filegroups

=cut

sub _validate_filegroups_nonempty {
    my $self   = shift;
    my $volume = $self->{volume};

    my $prev_filecount      = undef;
    my $prev_filegroup_name = q{};
    my $filegroups = $volume->get_file_groups();
    while ( my ( $filegroup_name, $filegroup ) =
        each( %{$filegroups} ) )
    {
        $logger->debug("validating nonempty filegroup $filegroup_name");
        my $filecount = scalar( @{$filegroup} );
        if ( !$filecount ) {
           $self->_set_error("File group $filegroup is empty");
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
        each( %{ $filegroups } ) )
    {
        push( @filegroup_names, $filegroup_name );
        foreach my $file ( @{$filegroup} ) {
            if ( $file =~ /(\d+)\.(\w+)$/ ) {
                my $sequence_number = $1;
                $files{$sequence_number}{$filegroup_name} = $file;
            }
            else {
               $self->_set_error(
"Can't extract sequence number from filename $file in group $filegroup_name"
                );
            }
        }
    }

    # Make sure there are no gaps in the sequence
    if ( !$volume->get_nspkg->get('allow_sequence_gaps') ) {
        my $prev_sequence_number = 0;
        my @sequence_numbers     = sort( keys(%files) );
        foreach my $sequence_number (@sequence_numbers) {
            if ( $sequence_number > $prev_sequence_number + 1 ) {
               $self->_set_error(
"Skip sequence number from $prev_sequence_number to $sequence_number"
                );
            }
            $prev_sequence_number = $sequence_number;
        }
    }

    # Make sure each filegroup has an object for each sequence number
    while ( my ( $sequence_number, $files ) = each(%files) ) {
        if ( keys( %{ $files } ) != @filegroup_names ) {
           $self->_set_error(
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
    my $self          = shift;
    my $volume        = $self->{volume};
    my $checksums     = $volume->get_checksums();
    my $checksum_file = $volume->get_checksum_file();
    my $path = $volume->get_staging_directory();

   # make sure we check every file in the directory except for the checksum file
   # and make sure we check every file in the checksum file

    my @tovalidate = uniq(
        sort( ( @{ $volume->get_all_directory_files() }, 
              keys( %{ $volume->get_checksums() } ) ) ) );

    foreach my $file (@tovalidate) {
        next if $file eq $checksum_file;
        my $expected = $checksums->{$file};
        if ( not defined $expected ) {
           $self->_set_error("No checksum found for $file");
        }
        elsif ( md5sum("$path/$file") ne $expected ) {
           $self->_set_error("Checksums check failed for $file");
        }

    }

    return;

}

=item _validate_utf8

Opens and tries to decode each file alleged to be UTF8 and ensures that it is 
valid UTF8 and does not contain any control characters other than tab and CR.

=cut

sub _validate_utf8 {
    my $self = shift;
    my $volume = $self->{volume};
    my $utf8_files = $volume->get_utf8_files();
    my $path = $volume->get_staging_directory();

    foreach my $utf8_file (@$utf8_files) {
	eval {
	    my $utf8_fh;
	    open($utf8_fh,"<","$path/$utf8_file") or croak("Can't open $utf8_file: $!");
	    local $/ = undef; # turn on slurp mode
	    binmode($utf8_fh,":bytes"); # ensure we're really reading it as bytes
	    my $utf8_contents = <$utf8_fh>;
	    my $decoded_utf8 = decode("utf-8-strict",$utf8_contents,Encode::FB_CROAK); # ensure it's really valid UTF-8 or croak

	    croak("Invalid control characters in file $utf8_file") if $decoded_utf8 =~ /[\x00-\x08\x0B-\x1F]/m;
	    close($utf8_fh);
	};
	if($@) {
	    $self->_set_error("UTF8 validation failed for $utf8_file: $@");
	}

    }
}

=item _validate_metadata

Runs JHOVE on all the files for the given volume and validates their metadata.

=cut

sub _validate_metadata {
    my $self   = shift;
    my $volume = $self->{volume};



    # get xpc
    my $jhove_xpc;
    {
	my $jhove_xml = _run_jhove( $volume );
        my $jhove_parser = XML::LibXML->new();
        my $jhove_doc    = $jhove_parser->parse_string($jhove_xml);
        $jhove_xpc = XML::LibXML::XPathContext->new($jhove_doc);
    }
    
    register_namespaces($jhove_xpc);
    
    # get repInfo nodes
    my $nodelist = $jhove_xpc->findnodes('//jhove:repInfo');

    while (my $node = $nodelist->pop()) {
	# run module validator
	# get uri for this node
	my $file = $jhove_xpc->findvalue( '@uri', $node );
	# remove leading whitespace
	$file =~ s/^\s*//g;

	$logger->debug("validating $file");
	my $mod_val = HTFeed::ModuleValidator->new(
	    xpc      => $jhove_xpc,
	    node     => $node,
	    volume   => $volume,
	    filename => $file
	);
	$mod_val->run();

	# check, log success
	if ( $mod_val->succeeded() ) {
	    $logger->debug("$file ok");
	}
	else {
	   $self->_set_error("$file bad");
	}
    }

    return;

}

# run jhove
sub _run_jhove {
    my $volume = shift;
    my $dir = $volume->get_staging_directory();
    my $files = $volume->get_metadata_files();
    # prepend directory to each file to validate
    my $files_for_cmd = join(' ', map { "$dir/$_"} @$files);

    $logger->trace("jhove run on $dir started");
    my $xml = `jhove -h XML -c /l/local/jhove-1.5/conf/jhove.conf $files_for_cmd`;
    $logger->trace("jhove run on $dir finished");
    
    return $xml;
}

sub md5sum {
    my $file = shift;
    my $ctx = new Digest::MD5;
    my $fh;
    open($fh,"<",$file) or croak("Can't open $file: $!");
    $ctx->addfile($fh);
    close($fh);
    return $ctx->hexdigest();
}
1;

__END__;
