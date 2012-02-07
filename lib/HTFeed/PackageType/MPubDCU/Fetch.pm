package HTFeed::PackageType::MPubDCU::Fetch;

use strict;
use warnings;
use base qw(HTFeed::Stage::Fetch);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

sub run {
    my $self = shift;
    my $volume = $self->{volume};
    my $packagetype = $volume->get_packagetype();
    my $objid = $volume->get_objid();

    my $fetch_dir = get_config('staging'=>'fetch');
    my $source = "$fetch_dir/$packagetype/forHT/$objid";
    my $dest = get_config('staging' => 'preingest');

    $self->fetch_from_source($source,$dest);
    $self->fix_line_endings($dest);

    $self->_set_done();
    return $self->succeeded();
}

1;

