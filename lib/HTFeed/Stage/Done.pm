package HTFeed::Stage::Done;

# Placeholder stage to clean up if not collating.

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);

sub run{
    my $self = shift;

    $self->_set_done();
    return $self->succeeded();
    return;
}


sub stage_info{
    return {success_state => 'done', failure_state => 'punted'};
}

sub clean_always{
    my $self = shift;
    $self->{volume}->clean_mets();
    $self->{volume}->clean_zip();
    $self->{volume}->clear_premis_events();
    $self->{volume}->clean_download();
}

1;

__END__
