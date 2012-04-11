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
use HTFeed::Config qw(get_config);

use base qw(HTFeed::Stage::JHOVE_Runner);


sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    if(not defined $self->{run_stages}) {
        $self->{run_stages} = $self->{volume}->get_nspkg()->get('validation_run_stages');
    }
    $self->{stages} = {
        validate_file_names          => \&_validate_file_names,
        validate_filegroups_nonempty => \&_validate_filegroups,
        validate_consistency         => \&_validate_consistency,
        validate_checksums           => \&_validate_checksums,
        validate_utf8                => \&_validate_utf8,
        validate_metadata            => \&_validate_metadata
    };

    return $self;

}

sub run {
    my $self = shift;


    # Run each enabled stage
    foreach my $stage ( @{$self->{run_stages}} ) {
        if ( exists( $self->{stages}{$stage} ) ) {
            my $sub = $self->{stages}{$stage};
            get_logger()->debug("Running validation stage $stage");

            &{$sub}($self);


        }
        else {
            croak("Undefined validation stage $stage requested");
        }
    }

    # do this last
    $self->_set_done();
    if ( !$self->failed() ) {
        $self->{volume}->record_premis_event( 'package_validation',
            outcome => PREMIS::Outcome->new('pass') );
    }

    return;
}

sub stage_info {
    return { success_state => 'validated', failure_state => 'punted' };
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
        $self->set_error(
            "BadFilename",
            field => 'filename',
            file  => $file
        );

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

    my $filegroups = $volume->get_file_groups();
    while ( my ( $filegroup_name, $filegroup ) = each( %{$filegroups} ) ) {
        get_logger()->debug("validating nonempty filegroup $filegroup_name");
        my $filecount = scalar( @{ $filegroup->get_filenames() } );
        if ( !$filecount and $filegroup->get_required() ) {
            $self->set_error( "BadFilegroup", filegroup => $filegroup );
        }
    }

    return;
}

=item _validate_consistency

Make sure every listed file in each file group (ocr, text, etc.) has exactly one
corresponding file in each other file group, that there are no sequence skips

=cut

sub _validate_consistency {
    my $self   = shift;
    my $volume = $self->{volume};

    my $filegroups = $volume->get_file_groups();
    my @filegroup_names = grep { $filegroups->{$_}->get_required() } keys(%$filegroups);

    my $files = $volume->get_required_file_groups_by_page();

    # Make sure there are no gaps in the sequence
    if ( !$volume->get_nspkg->get('allow_sequence_gaps') ) {
        my $prev_sequence_number = 0;
        my @sequence_numbers     = sort( keys(%$files) );
        foreach my $sequence_number (@sequence_numbers) {
            if ( $sequence_number > $prev_sequence_number + 1 ) {
                $self->set_error( "MissingFile",
                    detail =>
                    "Skip sequence number from $prev_sequence_number to $sequence_number"
                );
            }
            $prev_sequence_number = $sequence_number;
        }
    }

    # Make sure each filegroup has exactly one object for each sequence number
    while ( my ( $sequence_number, $files ) = each( %{$files} ) ) {
        if ( keys( %{$files} ) != @filegroup_names ) {
            $self->set_error( "MissingFile",
                detail => "File missing for $sequence_number: have "
                . join( q{,}, keys %{$files} )
                . '; expected '
                . join( q{,}, @filegroup_names ) );
        } else {
            if( !$volume->get_nspkg->get('allow_multiple_pageimage_formats')) {
                while ( my ($type, $list) = each %{$files}){
                    if(scalar(@$list) ne 1){
                        $self->set_error("BadFile", detail=>"Extraneous files for $sequence_number: have "
                            . join( q{,}, @$list)
                            . '; expected only one file' );
                    }
                }
            }
        }
    }
}


=item _validate_checksums

Validate each file against a precomputed list of checksums.

=cut

sub _validate_checksums {
    my $self             = shift;
    my $volume           = $self->{volume};
    my $checksums        = $volume->get_checksums();
    my $checksum_file    = $volume->get_nspkg()->get('checksum_file');
    my $source_mets_file = $volume->get_source_mets_file();
    my $path             = $volume->get_staging_directory();

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
        next if $source_mets_file and $file eq $source_mets_file;
        next if $checksum_file and $file =~ $checksum_file;
        my $expected = $checksums->{$file};
        if ( not defined $expected ) {
            $self->set_error(
                "BadChecksum",
                field  => 'checksum',
                file   => $file,
                detail => "File present in package but not in checksum file"
            );
        }
        elsif ( !-e "$path/$file" ) {
            $self->set_error(
                "MissingFile",
                file => $file,
                detail =>
                "File listed in checksum file but not present in package"
            );
        }
        elsif ( ( my $actual = md5sum("$path/$file") ) ne $expected ) {
            $self->set_error(
                "BadChecksum",
                field    => 'checksum',
                file     => $file,
                expected => $expected,
                actual   => $actual
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
            $self->set_error(
                "BadUTF",
                field  => 'utf8',
                detail => "$@",
                file   => $utf8_file
            );
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
    my $dir   = $volume->get_staging_directory();
    my $files = $volume->get_jhove_files();


    $self->run_jhove($volume,$dir,$files, sub {
            my ($volume,$file,$node) = @_;

            my $xpc = XML::LibXML::XPathContext->new($node);
            register_namespaces($xpc);

            get_logger()->trace("validating $file");
            my $mod_val = HTFeed::ModuleValidator->new(
                xpc => $xpc,

                #node    => $node,
                volume   => $volume,
                filename => $file
            );
            $mod_val->run();

            # check, log success
            if ( $mod_val->succeeded() ) {
                get_logger()->debug( "File validation succeeded",
                    file => $file );
            }
            else {
                $self->set_error( "BadFile", file => $file );
            }
        });

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

# do cleaning that is appropriate after failure
sub clean_failure {
    my $self = shift;

    $self->{volume}->clean_unpacked_object();
}

1;

__END__;
## Please see file perltidy.ERR
