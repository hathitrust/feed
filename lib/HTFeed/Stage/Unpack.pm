package HTFeed::Stage::Unpack;

use warnings;
use strict;

use HTFeed::Stage::DirectoryMaker;
use base qw(HTFeed::Stage::DirectoryMaker Exporter);

use HTFeed::JobMetrics;
use Log::Log4perl qw(get_logger);
our @EXPORT_OK = qw(unzip_file);

sub stage_info{
    return {
	success_state => 'unpacked',
	failure_state => 'ready'
    };
}

# unzip_file $self,$infile,$outdir,$otheroptions
sub unzip_file {
    # extract - not using Archive::Zip because it doesn't handle ZIP64
    return _extract_file(
	q(yes 'n' 2>/dev/null | unzip -LL -j -o -q '%s' -d '%s' %s 2>&1),
	@_
    );
}

# unzip_file $self,$infile,$outdir,$otheroptions
sub unzip_file_preserve_case {
    # extract - not using Archive::Zip because it doesn't handle ZIP64
    return _extract_file(
	q(yes 'n' 2>/dev/null | unzip -j -o -q '%s' -d '%s' %s 2>&1),
	@_
    );
}

# untgz_file $self,$infile,$outdir,$otheroptions
sub untgz_file {
    # extract - not using Archive::Tar because it is very slow
    return _extract_file(
	q(tar -zx -f '%s' -C '%s' %s 2>&1),
	@_
    );
}

sub untar_file {
    # extract - not using Archive::Tar because it is very slow
    return _extract_file(
	q(tar -x -f '%s' -C '%s' %s 2>&1),
	@_
    );
}

sub _extract_file {
    my $command      = shift;
    my $requester    = shift; # not necessarily self..
    my $infile       = shift;
    my $outdir       = shift;
    my $otheroptions = shift || '';

    my $job_metrics  = HTFeed::JobMetrics->new;
    my $start_time   = $job_metrics->time;

    my $full_command = sprintf($command, $infile, $outdir, $otheroptions);
    get_logger()->trace("Extracting $infile with command $full_command");

    # make directory
    if (not -d $outdir) {
	mkdir($outdir, 0770) or $requester->set_error(
	    'OperationFailed',
	    operation => 'mkdir',
	    detail    => "$outdir could not be created"
	);
    }

    if (not -e $infile) {
        $requester->set_error('MissingFile', file => $infile);
    }

    my $infile_size = -s $infile;
    my $rstring     = `$full_command`;
    my $rval        = $?;

    # 1 is a non-fatal warning for both tar and unzip...
    # ignore it and let manifest / validation stuff figure it out
    if ($rval != 0 and $rval != (1 << 8)) {
        $requester->set_error(
	    'OperationFailed',
	    operation  => 'unzip',
	    exitstatus => $rval,
	    detail     => $rstring
	);
        return;
    }

    # We don't use $self here, so we have to get job_metrics a different way.
    my $end_time    = $job_metrics->time;
    my $delta_time  = $end_time - $start_time;
    $job_metrics->add("ingest_unpack_seconds_total", $delta_time);
    my $outdir_size = $job_metrics->dir_size($outdir);
    $job_metrics->add("ingest_unpack_bytes_r_total", $infile_size);
    $job_metrics->add("ingest_unpack_bytes_w_total", $outdir_size);
    $job_metrics->inc("ingest_unpack_items_total");
    get_logger()->trace("Extracting $infile succeeded");

    return 1;
}

1;
