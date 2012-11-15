package HTFeed::Stage::RepositoryUnpack;

use warnings;
use strict;

use base qw(HTFeed::Stage::Unpack);

sub run{
    my $self = shift;
    # make staging directories
    $self->SUPER::run();
    my $volume = $self->{volume};

    my $zipfile = $volume->get_repository_zip_path();
    # check that file exists
    if (-e $zipfile){
        # unpack only .txt files
        $self->unzip_file($zipfile,$volume->get_staging_directory()) or return;
        # add link to zip file for METS regeneration
        system("ln -s '$zipfile' '" . $volume->get_zip_directory() . "'");
    }
    else{
        $self->set_error('MissingFile',file=>$zipfile);
        return;
    }

    $self->_set_done();
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'uplift_unpacked', failure_state => ''};
}

sub clean_failure{
    my $self = shift;
    return $self->{volume}->clean_unpacked_object();
}

1;

__END__
