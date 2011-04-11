package HTFeed::PackageType::IA::VerifyManifest;

use warnings;
use strict;
use IO::Handle;
use IO::File;
use List::MoreUtils qw(any);

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);

# Verifies that all files listed in the manifest exist and that their checksums
# match those provided in the source METS.

sub run {
    my $self   = shift;
    my $volume = $self->{volume};
    my $objid  = $volume->get_objid();
    my $ia_id = $volume->get_ia_id();

    my $objdir   = $volume->get_download_directory();
    my $manifest = "${ia_id}_files.xml";
    my $mismatch_ok_files = [ "${ia_id}_meta.xml" ];

    if(!-e "$objdir/$manifest") {
        get_logger()->warn("FileMissing","${ia_id}_files.xml");
        my $outcome = new PREMIS::Outcome('warning');
        $outcome->add_detail_note("Manifest ${ia_id}_files.xml not found, fixity check could not be performed");
        $volume->record_premis_event("source_md5_fixity",outcome => $outcome);
    } else {
        my $parser = new XML::LibXML;
        my $doc = $parser->parse_file( "$objdir/$manifest" );

        opendir(my $dir, $objdir) or die("Can't opendir $objdir: $!");
        # only get plain files
        my %dirfiles = map { ($_ => 1) } grep { -f $_ } readdir($dir);
        closedir($dir);

        my $core_mismatch = 0;
        my @mismatch = ();
        my @passed = ();
        foreach my $file ($doc->findnodes("//file")) {
            my $filename = $file->getAttribute("name");
            my $md5 = $file->findvalue("./md5");

            # files that always seem to be wrong
            my $mismatch_nonfatal = any { $_ eq $filename } @$mismatch_ok_files;

            if(-e ("$objdir/$filename")) {
                delete($dirfiles{$filename});
                next if $filename eq $manifest; # manifest file, will always be wrong
                if( $self->_check_md5sum($objdir,$filename,$md5,$mismatch_nonfatal) ) {
                    push(@passed,$filename);
                } elsif($mismatch_nonfatal) {
                    push(@mismatch,$filename);
                } else {
                    $core_mismatch = 1;
                } 
            }

        }

        my @unchecked = keys(%dirfiles);
        my $outcome;
        if($core_mismatch)  {
            $outcome = new PREMIS::Outcome('fail');
        } elsif(@mismatch) {
            $outcome = new PREMIS::Outcome('warning');
            $outcome->add_file_list_detail( "files failed checksum validation",
                            "failed", \@mismatch);
        } else {
            $outcome = new PREMIS::Outcome('pass');
        }
        $outcome->add_file_list_detail("files passed checksum validation",
            "passed", \@passed);
        $outcome->add_file_list_detail("files not checked",
            "unchecked", \@unchecked);
        $volume->record_premis_event('source_md5_fixity',outcome => $outcome);
    }

    $self->_set_done();
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'manifest_verified', failure_state => 'punted'};
}

=item $obj->_check_md5sum($path,$file,$manifest_md5sum,$mismatch_nonfatal)

Verifies an md5 checksum for a single path. If mismatch_nonfatal is given and 
is true, will only log a warning instead of an error.

=cut

sub _check_md5sum($$) {
    my $self            = shift;
    my $path = shift;
    my $file = shift;
    my $manifest_md5sum = shift;
    my $mismatch_nonfatal = shift;

    my $md5sum = md5sum("$path/$file");
    if ( $md5sum eq $manifest_md5sum ) {
        get_logger()->trace("Verified $file $md5sum");
        return 1;
    }
    else {
        my @error_params = (
            "BadChecksum",
            field    => 'checksum',
            file     => $file,
            expected => $manifest_md5sum,
            actual   => $md5sum
        );

        if($mismatch_nonfatal) {
            get_logger()->warn(@error_params);
        } else {
            $self->set_error(@error_params);
        }
        return 0;
    }
}

=item md5sum($file)

Returns the md5 checksum for the given file, or throws an exception if the file cannot be read.

=cut

sub md5sum($) {
    my $file = shift;

    my $fh = new IO::File("<$file") or die("Can't open '$file': $!");
    $fh->binmode();

    return Digest::MD5->new->addfile($fh)->hexdigest;
    $fh->close();
}

# do cleaning that is appropriate after failure
sub clean_failure{
    my $self = shift;
    $self->clean_download();
}

1;

__END__
