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
use IO::Pipe;
use PREMIS::Outcome;

use base qw(HTFeed::Stage);

my $logger = get_logger(__PACKAGE__);

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    $self->{stages} = {
        validate_file_names          => \&_validate_file_names,
        validate_filegroups	     => \&_validate_filegroups,
        validate_consistency         => \&_validate_consistency,
        validate_checksums           => \&_validate_checksums,
        validate_utf8                => \&_validate_utf8,
        validate_metadata            => \&_validate_metadata
    };

    $self->{run_stages} = [
        qw(validate_file_names
          validate_filegroups
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
    foreach my $stage ( @{ $self->{run_stages} } ) {
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
    if(!$self->failed()) {
	$self->{volume}->record_premis_event('package_validation',
	    outcome => PREMIS::Outcome->new('pass'));
    } 

    return;
}

=item _validate_file_names

Ensures every file in the AIP staging directory is valid for the volume.

=cut

sub _validate_file_names {
    my $self   = shift;
    my $volume = $self->{volume};

    my $valid_file_pattern = $volume->get_nspkg()->get('valid_file_pattern');
    my @bad                = grep(
        { !/$valid_file_pattern/ } @{ $volume->get_all_directory_files() } );

    foreach my $file (@bad) {
        $self->set_error( "BadFilename", field => 'filename', file => $file );

    }

    return;

}

=item _validate_filegroups

Ensure that every listed filegroup (image, ocr, etc.) contains at least one file.

TODO: Use required filegroups from ns/packagetype config
TODO: Use filegroup patterns from ns/packagetype config to populate filegroups

=cut

sub _validate_filegroups {
    my $self   = shift;
    my $volume = $self->{volume};

    my $filegroups          = $volume->get_file_groups();
    while ( my ( $filegroup_name, $filegroup ) = each( %{$filegroups} ) ) {
        $logger->debug("validating nonempty filegroup $filegroup_name");
        my $filecount = scalar( @{$filegroup->get_filenames()} );
        if ( !$filecount ) {
            $self->set_error("BadFilegroup", filegroup => $filegroup);
        }
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

    my @filegroup_names = keys( %{ $volume->get_file_groups(); } );
    my $files = $volume->get_file_groups_by_page();

    # Make sure there are no gaps in the sequence
    if ( !$volume->get_nspkg->get('allow_sequence_gaps') ) {
        my $prev_sequence_number = 0;
        my @sequence_numbers     = sort( keys(%$files) );
        foreach my $sequence_number (@sequence_numbers) {
            if ( $sequence_number > $prev_sequence_number + 1 ) {
                $self->set_error("MissingFile", detail => "Skip sequence number from $prev_sequence_number to $sequence_number");
            }
            $prev_sequence_number = $sequence_number;
        }
    }

    # Make sure each filegroup has an object for each sequence number
    while ( my ( $sequence_number, $files ) = each( %{$files} ) ) {
        if ( keys( %{$files} ) != @filegroup_names ) {
            $self->set_error( "MissingFile", detail => 
                "File missing for $sequence_number: have "
                  . join( q{,}, keys %{$files} )
                  . '; expected '
                  . join( q{,}, @filegroup_names )
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
#    my $checksum_file = $volume->get_checksum_file();
    my $path          = $volume->get_staging_directory();

   # make sure we check every file in the directory except for the checksum file
   # and make sure we check every file in the checksum file

    my @tovalidate = uniq(
        sort( (
                @{ $volume->get_all_directory_files() },
                keys( %{ $volume->get_checksums() } )
            ) )
    );

    my @bad_files = ();

    foreach my $file (@tovalidate) {
#        next if $file eq $checksum_file;
        my $expected = $checksums->{$file};
        if ( not defined $expected ) {
            $self->set_error("BadChecksum",field => 'checksum',file => $file, detail => "File present in package but not in checksum file");
        }
	elsif ( ! -e "$path/$file") {
	    $self->set_error("BadChecksum",file => $file, detail => "File listed in checksum file but not present in package");
	}
        elsif ( (my $actual = md5sum("$path/$file")) ne $expected ) {
            $self->set_error("BadChecksum", field => 'checksum', file => $file, expected => $expected, actual => $actual);
	    push(@bad_files,"$file");
        }

    }

    my $outcome;
    if(@bad_files) {
	$outcome = PREMIS::Outcome->new('warning');
	$outcome->add_file_list_detail("files failed checksum validation","failed",\@bad_files);
    } else {
	$outcome = PREMIS::Outcome->new('pass');
    }
    $volume->record_premis_event('page_md5_fixity',outcome => $outcome);

    return;

}

=item _validate_utf8

Opens and tries to decode each file alleged to be UTF8 and ensures that it is 
valid UTF8 and does not contain any control characters other than tab and CR.

=cut

sub _validate_utf8 {
    my $self       = shift;
    my $volume     = $self->{volume};
    my $utf8_files = $volume->get_utf8_files();
    my $path       = $volume->get_staging_directory();

    foreach my $utf8_file (@$utf8_files) {
        eval {
            my $utf8_fh;
            open( $utf8_fh, "<", "$path/$utf8_file" )
              or croak("Can't open $utf8_file: $!");
            local $/ = undef;    # turn on slurp mode
            binmode( $utf8_fh, ":bytes" )
              ;                  # ensure we're really reading it as bytes
            my $utf8_contents = <$utf8_fh>;
            my $decoded_utf8 =
              decode( "utf-8-strict", $utf8_contents, Encode::FB_CROAK )
              ;                  # ensure it's really valid UTF-8 or croak
            croak("Invalid control characters in file $utf8_file")
              if $decoded_utf8 =~ /[\x00-\x08\x0B-\x1F]/m;
            close($utf8_fh);
        };
        if ($@) {
            $self->set_error("BadUTF",field => 'utf8',detail => "@_",file => $utf8_file);
        }

    }
}

=item _validate_metadata

Runs JHOVE on all the files for the given volume and validates their metadata.

=cut

sub _validate_metadata {
    my $self   = shift;
    my $volume = $self->{volume};
	
	# get files
    my $dir = $volume->get_staging_directory();
    my $files = $volume->get_jhove_files();
    
    # make sure we have >0 files
    if (! @$files){
        $self->set_error("BadFile",file => "all",detail => "Zero files found to validate");
        return;
    }
    
    # prepend directory to each file to validate
    my $files_for_cmd = join(' ', map { "$dir/$_"} @$files);
	my $jhove_cmd = 'jhove -h XML -c /l/local/jhove-1.5/conf/jhove.conf ' . $files_for_cmd;
	
	# make a hash of expected files
	my %files_left_to_validate = map { $_ => 1 } @$files;

    # open pipe to jhove
    my $pipe = IO::Pipe->new();
    $pipe->reader($jhove_cmd);
    
    # get the header
    my $control_line = <$pipe>;
    my $head = <$pipe>;
    my $date_line = <$pipe>;
    my $tail='</jhove>';
    
    # start looking for repInfo block
    DOC_READER: while(<$pipe>){
        if (m|^\s<repInfo.+>$|){
            # save the fisrt line when we find it
            my $xml_block = "$_";

            # get the rest of the lines for this repInfo block
            BLOCK_READER: while(<$pipe>){
                # save more lines until we get to </repInfo>
                $xml_block .= $_;
                last BLOCK_READER if m|^\s</repInfo>$|;
            }

            # get file name from xml_block
            $xml_block =~ m{\s<repInfo\suri=".*/(.*)"|\s<repInfo\suri="(.*)"};
            my $file;
            $file = $1 or $file = $2;
			
            # remove file from our list
            delete $files_left_to_validate{$file};
			
            # validate file
            {
                # put the headers on xml_block, parse it as a doc
                $xml_block = $control_line . $head . $date_line . $xml_block . $tail;
                my $parser = XML::LibXML->new();
                $xml_block = $parser->parse_string($xml_block);
                my $xpc = XML::LibXML::XPathContext->new($xml_block);
                register_namespaces($xpc);

            	$logger->trace("validating $file");
            	my $mod_val = HTFeed::ModuleValidator->new(
            	    xpc      => $xpc,
            	    #node    => $node,
            	    volume   => $volume,
            	    filename => $file
            	);
            	$mod_val->run();

            	# check, log success
            	if ( $mod_val->succeeded() ) {
            	    $logger->debug("File validation succeeded",file => $file);
            	}
            	else {
            	    $self->set_error("BadFile",file => $file);
            	}
            }

        }
        elsif(m|^</jhove>$|){
            last DOC_READER;
        }
        elsif(m|<app>|){
            # jhove was run on zero files, that should never happen
            $logger->fatal("FatalError", detail => "jhove was run on zero files", volume => $volume->get_objid() );
            croak "jhove was run on zero files";
        }
        else{
            # this should never happen
            die "jhove output bad";
        }
    }

    if (keys %files_left_to_validate){
        # this should never happen
        die "missing a block in jhove output";
    };

    return;
}

sub md5sum {
    my $file = shift;
    my $ctx  = Digest::MD5->new();
    my $fh;
    open( $fh, "<", $file ) or croak("Can't open $file: $!");
    $ctx->addfile($fh);
    close($fh);
    return $ctx->hexdigest();
}
1;

__END__;
