package HTFeed::PackageType::DLXS::ImageRemediate;

use warnings;
use strict;
use base qw(HTFeed::Stage::ImageRemediate);

use Log::Log4perl qw(get_logger);
use File::Basename;
use HTFeed::XMLNamespaces qw(register_namespaces);

sub run{
    my $self = shift;
    my $volume = $self->{volume};
    my $preingest_path = $volume->get_preingest_directory();
    my $stage_path = $volume->get_staging_directory();
    

    my $repStatus_xp = XML::LibXML::XPathExpression->new('/jhove:jhove/jhove:repInfo/jhove:status');
    my $error_xp = XML::LibXML::XPathExpression->new('/jhove:jhove/jhove:repInfo/jhove:messages/jhove:message[@severity="error"]');

    # remediate TIFFs
    my @tiffs = glob("$preingest_path/*.tif");
    my $directory = $preingest_path;
    @tiffs = map { basename($_) } @tiffs;

    $self->run_jhove($volume,$directory,\@tiffs, sub {
        my ($volume,$file,$node) = @_;
        my $xpc = XML::LibXML::XPathContext->new($node);
        register_namespaces($xpc);
        
        $self->{jhoveStatus} = $xpc->findvalue($repStatus_xp);
        $self->{jhoveErrors} = [map { $_->textContent } $xpc->findnodes($error_xp)];

        $self->remediate_image("$preingest_path/$file","$stage_path/$file");
    });

    # remediate JP2s

    foreach my $jp2_submitted (glob("$preingest_path/*.jp2"))
    {
        my $jp2_remediated = basename($jp2_submitted);
        # change to form 0000010.jp2 instead of p0000010.jp2
        $jp2_remediated =~ s/^p/0/;
        $jp2_remediated = "$stage_path/$1_$2.jp2";

        $self->remediate_image( $jp2_submitted, $jp2_remediated );
    }

    $volume->record_premis_event('image_header_modification');
    
    $self->_set_done();
    return $self->succeeded();
}

1;

__END__
