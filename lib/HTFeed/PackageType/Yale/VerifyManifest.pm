package HTFeed::PackageType::Yale::VerifyManifest;

use warnings;
use strict;
use IO::Handle;
use IO::File;

use base qw(HTFeed::Stage);
use HTFeed::Config qw(get_config);

use Log::Log4perl qw(get_logger);
my $logger = get_logger(__PACKAGE__);

# Verifies that all files listed in the manifest exist and that their checksums
# match those provided in the source METS.

sub run {
    my $self   = shift;
    my $volume = $self->{volume};
    my $objid  = $volume->get_objid();

    my $objdir   = $volume->get_preingest_directory();
    my $manifest = "$objdir/METADATA/${objid}_AllFilesManifest.txt";

    $logger->trace("Verifying checksums..");
    if ( -e $manifest ) {
        my $manifest_fh = new IO::File "<$manifest"
          or die("Can't open $manifest: $!");
        $manifest_fh->binmode(":crlf");    # it's DOS-tastic!

        while ( my $line = <$manifest_fh> ) {
            chomp($line);
            next if $line =~ /2Restore/;    # garbage files
            next if $line =~ /Thumbs.db/;
            my ( $dospath, $manifest_md5sum ) = split( "\t", $line );
            $self->_check_dospath_md5sum( $dospath, $manifest_md5sum );

        }
        $manifest_fh->close();
    }
    else {

        my $mets_xc = $volume->get_yale_mets_xpc();

        # check the METS file
        foreach my $file ( $mets_xc->findnodes("//mets:file") ) {
            my $dospath  = $file->findvalue('./mets:FLocat/@xlink:href');
            my $checksum = $file->findvalue('./@CHECKSUM');
            $self->_check_dospath_md5sum( $dospath, $checksum );
        }
    }
    $volume->record_premis_event('source_md5_fixity');
    $logger->trace("Done verifying checksums");

    $self->_set_done();
    return $self->succeeded();
}

sub stage_info{
    return {success_state => 'manifest_verified', failure_state => 'punt'};
}

=item $obj->_check_dospath_md5sum($dospath,$md5sum)

Verifies an md5 checksum for a single filename specified with a DOS-style pathname

=cut

sub _check_dospath_md5sum($$) {
    my $self            = shift;
    my $dospath         = shift;
    my $manifest_md5sum = shift;
    my $abspath         = $self->{volume}->dospath_to_path($dospath);
    if ( not defined $abspath ) {
        $self->set_error(
            "MissingFile",
            file   => $dospath,
            detail => "File listed in manifest but not present in package"
        );
    }
    my $md5sum = md5sum($abspath);
    if ( $md5sum eq $manifest_md5sum ) {
        $logger->trace("Verified $dospath $abspath $md5sum");
    }
    else {
        $self->set_error(
            "BadChecksum",
            field    => 'checksum',
            file     => $dospath,
            expected => $manifest_md5sum,
            actual   => $md5sum
        );
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

1;

__END__
