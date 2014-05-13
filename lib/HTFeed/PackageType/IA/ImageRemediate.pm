package HTFeed::PackageType::IA::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);
use Carp;
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);

sub run {
    my $self           = shift;
    my $volume         = $self->{volume};
    my $preingest_path = $volume->get_preingest_directory();
    my $stage_path     = $volume->get_staging_directory();
    my $objid          = $volume->get_objid();
    my $scandata_xpc   = $volume->get_scandata_xpc();

    opendir( my $dirh, "$preingest_path" )
        or croak("Can't opendir $preingest_path: $!");

    while ( my $file = readdir($dirh) ) {
        next unless $file =~ /(\d{4})\.jp2$/;
        my $seqnum = $1;
        my $new_filename = sprintf("%08d.jp2",$seqnum);
        my $jp2_submitted  = "$preingest_path/$file";
        my $jp2_remediated = "$stage_path/$new_filename";

        my $set_always_fields = {
            'XMP-dc:source'   => "$objid/$new_filename",
            'XMP-tiff:Artist' => 'Internet Archive'
        };

        my $set_if_undefined_fields = {};

        if ( my $capture_time = $self->get_capture_time($file) ) {
            $set_if_undefined_fields->{'XMP-tiff:DateTime'} = $capture_time;
        }

        my $resolution = $scandata_xpc->findvalue("//scribe:bookData/scribe:dpi | //bookData/dpi");

        # ignore missing resolution config
        eval {
            $resolution = $volume->get_nspkg()->get('resolution') if not defined $resolution or !$resolution;
        };


        $set_if_undefined_fields->{'Resolution'} = $resolution if defined $resolution and $resolution;

        $self->remediate_image(
            $jp2_submitted,     $jp2_remediated,
            $set_always_fields, $set_if_undefined_fields
        );

    }
    closedir($dirh);
    $volume->record_premis_event('image_header_modification');
    $volume->record_premis_event('file_rename');

    $self->_set_done();
    return $self->succeeded();
}

sub get_capture_time {
    my $self       = shift;
    my $image_file = shift;
    my $volume     = $self->{volume};
    my $xpc        = $volume->get_scandata_xpc();
    my $preingest_path = $volume->get_preingest_directory();

    # Get the time of creation from scandata.xml
    my $leafNum = int( $image_file =~ /_(\d{4}).jp2/ );
    # A couple places this might appear, and it might be with or without a namespace..
    my $gmtTimeStamp =
    $xpc->findvalue(qq(//scribe:pageData/scribe:page[\@leafNum='$leafNum']/scribe:gmtTimeStamp | //pageData/page[\@leafNum='$leafNum']/gmtTimeStamp));
    # TODO: Start or end time stamp? Or do we want to get it from the file?
    if( not defined $gmtTimeStamp or $gmtTimeStamp eq '') {
        $gmtTimeStamp = $xpc->findvalue('//scribe:scanLog/scribe:scanEvent/scribe:endTimeStamp | //scanLog/scanEvent/endTimeStamp');
    }

    if( not defined $gmtTimeStamp or $gmtTimeStamp eq '') {
        my $meta_xpc = $self->{volume}->get_meta_xpc();
        $gmtTimeStamp = $meta_xpc->findvalue('//scandate');
    }

    # use file time stamp if all else fails
    if( not defined $gmtTimeStamp or $gmtTimeStamp eq '') {
        $gmtTimeStamp = strftime("%Y%m%d%H%M%S",gmtime((stat("$preingest_path/$image_file"))[9]));
    }

    # Format is YYYYMMDDHHmmss
    if ( defined $gmtTimeStamp
            and $gmtTimeStamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/ )
    {
        return ("$1:$2:$3 $4:$5:$6+00:00");
    }

}

1;

__END__
