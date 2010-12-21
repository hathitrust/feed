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

sub unzip_file {
    my $requester = shift; # not necessarily always self..
    my $args = shift;
    my $file = shift;

    # try to repress 'broken pipe' message
    local $SIG{PIPE} = undef;
    $logger->trace("Unzipping $file");
    my $rstring = `yes 'n' | unzip $args -o -q $file`;
    my $rval = $?;
    if($rval or $rstring) {
        $requester->set_error('OperationFailed',operation=>'unzip',exitstatus=>$rval,detail=>$rstring);
        return;
    } else {
        $logger->trace("Unzipping $file succeeded");
        return 1;
    }
    # otherwise ok..
}

1;

__END__
