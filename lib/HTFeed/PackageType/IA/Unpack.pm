package HTFeed::PackageType::IA::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};

    my $download_dir = $volume->get_download_directory();
    my $preingest_dir = $volume->get_preingest_directory();
    my $objid = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();

    my $file = sprintf('%s/%s_jp2.zip',$download_dir,$ia_id);
    if(-e $file) {
        $self->unzip_file($file,$preingest_dir);
    }
    else { 
        $file =~ s/\.zip$/.tar/;
        $self->untar_file($file,$preingest_dir,"--strip-components 1");
    }

    opendir(my $dh, $preingest_dir) or die "Can't opendir $preingest_dir: $!";
    while(my $filename = readdir $dh) {

        # clean up wacky filenames to what is expected for deletecheck
        if ($filename =~ /(\d{4}).jp2$/) {
            my $newname = "${ia_id}_$1.jp2";
            rename("$preingest_dir/$filename","$preingest_dir/$newname") or die "Can't rename $filename to $newname: $!";
        }

    }
    closedir $dh;

    $self->_set_done();
    return $self->succeeded();
}

# do cleaning that is appropriate after failure
sub clean_failure{
    my $self = shift;
    $self->{volume}->clean_download();
    $self->{volume}->clean_preingest();
}


1;

__END__
