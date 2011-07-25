package HTFeed::PackageType::MPubDCU::METS;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use base qw(HTFeed::METS);


# Override base class _add_dmdsecs to not try to add MARC


sub _add_dmdsecs {
    my $self   = shift;
    my $volume = $self->{volume};
    my $mets   = $self->{mets};

    my $dmdsec =
      new METS::MetadataSection( 'dmdSec',
        'id' => $self->_get_subsec_id("DMD") );
    $dmdsec->set_md_ref(
        mdtype       => 'MARC',
        loctype      => 'OTHER',
        otherloctype => 'Item ID stored as second call number in item record',
        xptr         => $volume->get_identifier()
    );
    $mets->add_dmd_sec($dmdsec);

}

sub _add_source_mets_events {

	return;
}


1;
