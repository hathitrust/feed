#!/usr/bin/perl

package HTFeed::PackageType::DLXS::SourceMETS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use HTFeed::SourceMETS;
use HTFeed::XMLNamespaces qw(:namespaces :schemas register_namespaces);
use base qw(HTFeed::SourceMETS);
use HTFeed::METS;
use Image::ExifTool;


sub new {
    my $class  = shift;

    my $self = $class->SUPER::new(
	@_,

    );
    my $volume = $self->{volume};
    my $stage_path = $volume->get_staging_directory();
    my $pt_objid = $volume->get_pt_objid();
    $self->{outfile} = "$stage_path/DLXS_" . $pt_objid . ".xml";
    $self->{pagedata} = sub { $volume->get_srcmets_page_data(@_); };

    return $self;
}

# capture event is recorded in ImageRemediate stage
sub _add_capture_event {
    return;
}

1;
