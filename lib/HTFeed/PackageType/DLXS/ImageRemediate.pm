package HTFeed::PackageType::DLXS::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename;
use HTFeed::Config qw(get_tool_version);
use HTFeed::METS; # for premis timezone conversion
use POSIX qw(strftime);

# minimum dimensions for JP2 are set to trade paperback digitized at 400 DPI
my $MIN_XSIZE = 2128;
my $MIN_YSIZE = 3404;
#my $MIN_XSIZE = 1000;
#my $MIN_YSIZE = 1000;

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_path = $volume->get_preingest_directory();
    my $stage_path = $volume->get_staging_directory();
    my $seq_mapping = $volume->get_seq_mapping();

    $self->{real_capture_date} = 0;
    $self->{real_artist} = 0;

    # remediate TIFFs
    my @tiffs = map { basename($_) } glob("$preingest_path/[0-9]*.tif");
    $self->remediate_tiffs($volume,$preingest_path,\@tiffs,

        # return extra fields to set that depend on the file
        sub {
            my $file = shift;
            my $seq = $file;
            $seq =~ s/^(\d{4})....\.tif$/0000$1.tif/ if $volume->has_moa_filenames();
            $seq =~ s/\.tif$//;
            my $new_seq = $seq_mapping->{$seq};
            $self->set_error("BadField",field => "seqnum", actual => $seq,
                detail => "Can't find seq in pageview.dat") if not defined $new_seq;
            my $renamed_file = $new_seq . ".tif";

            # three fields to remediate: docname, datetime, artist.
            # docname: remediate only if missing; set to $barcode/$filename.
            # datetime: remediate from docname if possible. otherwise use loadcd.log
            # artist: remediate from docname if possible, otherwise use loadcd.log
            my $force_fields = {'IFD0:DocumentName' => join('/',$volume->get_objid(),$renamed_file) };
            my $set_if_undefined = {};
            if(my ($datetime,$artist) = $self->get_tiff_info("$preingest_path/$file",'tiff')) {
                $set_if_undefined->{'DateTime'} = $datetime;
                $set_if_undefined->{'IFD0:Artist'} = $artist;
            }

            return ( $force_fields, $set_if_undefined, $renamed_file);
        }
    );

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_path/*.jp2"))
    {
        my $jp2_remediated = basename($jp2_submitted);
        my $jp2_fields = $self->get_exiftool_fields($jp2_submitted);
        # change to form 0000010.jp2 instead of p0000010.jp2
        $jp2_remediated =~ s/^p/0/;
        $jp2_remediated =~ s/\.jp2$//;
        $jp2_remediated = $seq_mapping->{$jp2_remediated};
        $self->set_error("BadField",field => "seqnum", actual => $jp2_submitted,
            detail => "Can't find seq in pageview.dat") if not defined $jp2_remediated;
        $jp2_remediated = $jp2_remediated . ".jp2";

        # there shouldn't be any JP2s for MOA material?
        # $jp2_remediated =~ s/^(\d{4})....\.jp2$/0000$1.jp2/ if $jp2_remediated !~ /^0000/; 
        my $force_fields = {'XMP-dc:source' => join('/',$volume->get_objid(),$jp2_remediated) };
        my $set_if_undefined = {};
        $jp2_remediated = "$stage_path/$jp2_remediated";

        # get file timestamp??!
        $set_if_undefined->{'XMP-tiff:DateTime'} = strftime( "%Y:%m:%d %H:%M:%S%z", 
            localtime((stat($jp2_submitted))[9]));
        $set_if_undefined->{'XMP-tiff:Artist'} = 'University of Michigan';
        $self->{capture_date} = $set_if_undefined->{'XMP-tiff:DateTime'}
            if(not defined $self->{capture_date});
        $self->{artist} = $set_if_undefined->{'XMP-tiff:Artist'} if not defined $self->{artist};
        if(not defined $jp2_fields->{'XMP-tiff:DateTime'}) {
            $self->{missing_capture_date} = 1;
            $self->{missing_capture_date_method} = 'file timestamp';
            push(@{$self->{missing_capture_date_files}},basename($jp2_remediated));
        }
        if(not defined $jp2_fields->{'XMP-tiff:Artist'}) {
            $self->{default_artist} = 1;
            push(@{$self->{default_artist_files}},basename($jp2_remediated));
        }

        my $xsize  = $jp2_fields->{'Jpeg2000:ImageWidth'};
        my $ysize = $jp2_fields->{'Jpeg2000:ImageHeight'};

        # If resolution information isn't present in the image then assume we
        # scanned at 400 DPI; does that lead to a ridiculous physical size?  If
        # not set resolution to 400 if it is not already present.  Also, if
        # item has been manually checked (jpeg2000_size validation override is
        # set), just set to 400.

        if(not defined $jp2_fields->{'Jpeg2000:DisplayXResolution'}
            and not defined $jp2_fields->{'Jpeg2000:CaptureXResolution'}
            and not defined $jp2_fields->{'XMP-tiff:XResolution'})  {

          if( ($xsize >= $MIN_XSIZE and $ysize >= $MIN_YSIZE)
              or !$volume->should_check_validator('jpeg2000_size')) {

              $set_if_undefined->{'Resolution'} = '400/1';
          } else {
              $self->set_error("BadFile",
                  file => $jp2_submitted,
                  field => "Composite:ImageSize",
                  actual => $jp2_fields->{'Composite:ImageSize'},
                  expected => ">${MIN_XSIZE}x${MIN_YSIZE}"
              );
          }

          if(not defined $jp2_fields->{'Jpeg2000:CaptureXResolution'}) {
              $self->{jpeg2000_resolution} = 1;
              push(@{$self->{jpeg2000_resolution_files}}, basename($jp2_remediated));
          }
        }

        $self->remediate_image( $jp2_submitted, $jp2_remediated, $force_fields, $set_if_undefined );
    }

    $self->_add_image_remediate_event();
    $self->_add_capture_event();

    $self->_set_done();
    return $self->succeeded();
}

# extract DateTime and Artist from TIFF
sub get_tiff_info {
    my $self = shift;
    my $volume = $self->{volume};
    my $tiff = shift;
    my $fmt = shift;

    my ($load_date, $artist, $tiff_fields);

    if(-e $tiff) {
        $tiff_fields = $self->get_exiftool_fields($tiff);

        # first try the 'real' fields
        $artist = $tiff_fields->{'IFD0:Artist'};
        $load_date = $tiff_fields->{'IFD0:ModifyDate'};
        
        # next try DocumentName
        my $docname = $tiff_fields->{'IFD0:DocumentName'};
        my $eurodate = 0;
        if(defined $docname and $docname =~ /\Q",|NEH_\E/) {
            $eurodate = 1;
        }
        if(defined $docname and $docname =~ qr#^(\d{2})/(\d{2})/(\d{4}),(\d{2}):(\d{2}):(\d{2}),"(.*)"#) {
            if($eurodate) {
                $load_date = "$3:$2:$1 $4:$5:$6" if not defined $load_date or $load_date eq '';
            } else {
                $load_date = "$3:$1:$2 $4:$5:$6" if not defined $load_date or $load_date eq '';
            }
            $artist = $7 if not defined $artist or $artist eq '';
        }

        $self->{real_artist} = 1 if defined $artist and $artist ne '';
        $self->{real_capture_date} = 1 if defined $load_date and $load_date ne '';
    }

    my $loadcd_info = $volume->get_loadcd_info();
    $artist = $loadcd_info->{artist} if (not defined $artist or $artist eq '') and defined $loadcd_info->{artist};

    if(defined $loadcd_info->{load_date} and (not defined $load_date or $load_date eq '')) {
        $load_date = $loadcd_info->{load_date};
        # fix separator
        $load_date =~ s/-/:/g;
        $self->{missing_capture_date} = 1;
        $self->{missing_capture_date_method} = 'loadcd.log';
        push(@{$self->{missing_capture_date_files}},basename($tiff));
    }

    # set default artist and load date: file timestamp / University of Michigan

    if(not defined $load_date or $load_date eq '') {
        $load_date = strftime("%Y:%m:%d %H:%M:%S", localtime((stat($tiff))[9]));
        $self->{missing_capture_date} = 1;
        $self->{missing_capture_date_method} = 'file timestamp';
        push(@{$self->{missing_capture_date_files}},basename($tiff));
    }
    if(not defined $artist or $artist eq '') {
        $artist = "University of Michigan";
        $self->{default_artist} = 1;
        push(@{$self->{default_artist_files}},basename($tiff));
    }

    if($load_date =~ /^(\d{2})\/(\d{2})\/(9\d)$/) {
        # two digit date from the 1990s
        $load_date = "19$3-$1-$2 00:00:00";
    }

    $self->{'capture_date'} = $load_date if not defined $self->{'capture_date'};
    $self->{'artist'} = $artist if not defined $self->{'artist'};


    return ($load_date,$artist,$tiff_fields);
}

sub _add_capture_event {
    my $self = shift;
    my $volume = $self->{volume};

    my $capture_date = $self->{capture_date};
    if($capture_date =~ /^(\d{4}).(\d{2}).(\d{2}).(\d{2}).(\d{2}).(\d{2})(.*)/) {
        $capture_date = "$1-$2-$3T$4:$5:$6$7";
    }
    $capture_date = HTFeed::METS::convert_tz($self,$capture_date,"America/Detroit");
    my $eventid = $volume->make_premis_uuid('capture',$capture_date);

    my $event = new PREMIS::Event( $eventid, 'UUID', 
        'capture', $capture_date,
        'Initial capture of item');

    # Need note when capture date is not from original DateTime header.
    if(!$self->{real_capture_date}) {
        my $outcome = new PREMIS::Outcome('warning');
        $outcome->add_detail_note("Capture date may not be accurate: estimated from $self->{missing_capture_date_method}");
        $event->add_outcome($outcome);
    }
    # always just use michigan for the capture event.
    $event->add_linking_agent(
        new PREMIS::LinkingAgent( 'HathiTrust Institution ID',
            'umich', 
            'Executor' ) );

    $volume->record_premis_event('capture',custom_event => $event->to_node());
}

sub _add_image_remediate_event {
    my $self = shift;
    my $volume = $self->{volume};
    my $eventcode = 'image_header_modification';

    my $eventconfig = $self->{volume}->get_nspkg()->get_event_configuration($eventcode);
    my $eventid = $volume->make_premis_uuid($eventconfig->{'type'});
    my $event = new PREMIS::Event( $eventid, 'UUID', 
                                   $eventconfig->{'type'}, $volume->_get_current_date(),
                                   $eventconfig->{'detail'});

    $event->add_linking_agent(
        new PREMIS::LinkingAgent( $eventconfig->{'executor_type'}, 
            $eventconfig->{'executor'}, 
            'Executor' ) );

    my $tools_config = $eventconfig->{'tools'};
    foreach my $agent (@$tools_config) {
        $event->add_linking_agent(
            new PREMIS::LinkingAgent( 'tool', get_tool_version($agent), 'software')
        );
    }

    # Need note for image header modification:
    #   - if datetime header was missing and so we used loadcd or the file timestamp
    if($self->{missing_capture_date}) {
        my $outcome = new PREMIS::Outcome('warning');
        $outcome->add_file_list_detail("Image creation date metadata may not be accurate: estimated from $self->{missing_capture_date_method}",
            "estimated capture date",$self->{missing_capture_date_files});
            $event->add_outcome($outcome);
    }
    #   - if default artist was used
    if($self->{default_artist}) {
        my $outcome = new PREMIS::Outcome('warning');
        $outcome->add_file_list_detail("Original scanning artist unknown; digitization was performed under the direction of the recorded artist.",
            "default artist",$self->{default_artist_files});
        $event->add_outcome($outcome);
    }
    #   - if any jpeg2000s were present and 400 dpi resolution was used
    if($self->{jpeg2000_resolution}) {
        my $outcome = new PREMIS::Outcome('warning');
        $outcome->add_file_list_detail("Resolution estimated based on past practices and physical size.",
            "estimated resolution",$self->{jpeg2000_resolution_files});
        $event->add_outcome($outcome);
    }

    $volume->record_premis_event('image_header_modification',custom_event => $event->to_node());
}


1;

__END__
