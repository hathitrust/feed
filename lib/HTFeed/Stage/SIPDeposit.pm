package HTFeed::Stage::SIPDeposit;

use warnings;
use strict;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Path qw(make_path);

=head1 NAME

HTFeed::Stage::SIPDeposit.pm

=head1 SYNOPSIS

	SIP Deposit
	Copies completed zip file to specified directory

=cut

sub run{
    my $self = shift;

    my $volume = $self->{volume};
    my $namespace = $volume->get_namespace();
    my $objid = $volume->get_objid();

    my $mets_source = $volume->get_mets_path();
    my $zip_source = $volume->get_zip_path();

    my $output_path = get_config('sip_output') or die("set sip_output in feed configuration");
    mkdir($output_path);

    # make sure the operation will succeed
    if (-f $zip_source and -d $output_path){
        # move mets and zip to repo
        system('cp','-f',$zip_source,$output_path)
            and $self->set_error('OperationFailed', operation => 'cp', detail => "cp $zip_source $output_path failed with status: $?");

        $self->_set_done();
        return $self->succeeded();
    }
    
    # report which file(s) are missing
    my $detail = 'Collate failed, file(s) not found: ';
    $detail .= $mets_source unless(-f $mets_source);
    $detail .= $zip_source  unless(-f $zip_source);
    $detail .= $output_path unless(-d $output_path);
    
    $self->set_error('OperationFailed', detail => $detail);
    return;
}

sub stage_info{
    return {success_state => 'collated', failure_state => 'punted'};
}

sub clean_always{
    my $self = shift;
    $self->{volume}->clean_mets();
    $self->{volume}->clean_zip();
}

sub clean_success {
    my $self = shift;
    $self->{volume}->clear_premis_events();
    $self->{volume}->clean_sip_success();
}

1;

__END__

=pod

    INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
