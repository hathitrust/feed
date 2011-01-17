package HTFeed::Stage::Unpack;

use warnings;
use strict;

use base qw(HTFeed::Stage Exporter);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

our @EXPORT_OK = qw(unzip_file);

sub stage_info{
    return {success_state => 'unpacked', failure_state => 'ready'};
}

# unzip_file $self,$infile,$outdir,$otheroptions
sub unzip_file {
    # extract - not using Archive::Zip because it doesn't handle ZIP64
    return _extract_file(q(yes 'n' | unzip -j -o -q '%s' -d '%s' %s 2>&1),@_);
}

# untgz_file $self,$infile,$outdir,$otheroptions
sub untgz_file {
    # extract - not using Archive::Tar because it is very slow
    return _extract_file(q(tar --strip-components 1 -zx -f '%s' -C '%s' %s 2>&1),@_);
}

sub _extract_file {
    my $command = shift;
    my $requester = shift; # not necessarily self..
    my $infile = shift;
    my $outdir = shift;
    my $otheroptions = shift;

    $otheroptions = '' if not defined $otheroptions;

    $logger->trace("Extracting $infile with command $command");

    # make directory
    unless( -d $outdir or mkdir $outdir, 0770 ){
        $requester->set_error('OperationFailed',operation=>'mkdir',detail=>"$outdir could not be created");
        return;
    }

    unless( -e $infile ) {
        $requester->set_error('MissingFile',file=>$infile);
    }

    my $cmd = sprintf($command, $infile, $outdir, $otheroptions); 
    my $rstring = `$cmd`;
    my $rval = $?;
    if($rval or $rstring) {
        $requester->set_error('OperationFailed',operation=>'unzip',exitstatus=>$rval,detail=>$rstring);
        return;
    }

    $logger->trace("Extracting $infile succeeded");
    return 1;
}

1;

__END__
