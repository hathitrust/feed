package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::Fetch);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

sub run {
    my $self = shift;

    $self->SUPER::run();

    my $volume = $self->{volume};
    my $packagetype = $volume->get_packagetype();
    my $objid = $volume->get_objid();

    my $fetch_base = get_config('staging'=>'fetch');

    my $source = undef;


    my $base="$fetch_base/mpub_dcu";

    my @paths = grep { -d $_ } glob("$base/*");

    foreach my $path(@paths){
        if(-d  "$path/forHT/$objid" ){
            $self->set_error("BadFile",file => "$path/forHT/$objid", detail => "Duplicate submission $source") if defined $source;
            $source = "$path/forHT/$objid";
        }
    }

    my $dest = get_config('staging' => 'ingest');

    $self->fetch_from_source($source,$dest);
    $self->fix_line_endings($dest);

    $self->_set_done();
    return $self->succeeded();
}

1;
