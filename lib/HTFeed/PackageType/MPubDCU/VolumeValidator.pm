package HTFeed::PackageType::MPubDCU::VolumeValidator;

use warnings;
use strict;
use base qw(HTFeed::VolumeValidator);
use List::MoreUtils qw(uniq);
use HTFeed::Config;
use IO::Handle;
use IO::File;
use Digest::MD5;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{stages}{validate_checksums} = \&_validate_checksums;
    return $self;
}


sub _validate_checksums {

  	my $self             = shift;
    my $volume           = $self->{volume};
    my $checksums        = $volume->get_checksums();
    my $checksum_file    = $volume->get_nspkg()->get('checksum_file');
    my $path             = $volume->get_staging_directory();

    # make sure we check every file in the directory except for the checksum file
    # and make sure we check every file in the checksum file


my @tovalidate = uniq(
        sort( (
                @{ $volume->get_all_directory_files() },
                keys( %{ $volume->get_checksums() } )
            ) )
   );


    my @bad_files = ();

    foreach my $file (@tovalidate) {

        next if $checksum_file and $file =~ $checksum_file;
        my $expected = $checksums->{$file};
	
        if ( not defined $expected ) {
            $self->set_error(
                "BadChecksum",
                field  => 'checksum',
                file   => $file,
                detail => "File present in package but not in checksum file"
            );
        }

		elsif ( !-e "$path/$file" ) {
            $self->set_error(
                "MissingFile",
                file => $file,
                detail =>
                "File listed in checksum file but not present in package"
            );
        }
        elsif ( ( my $actual = md5sum("$path/$file") ) ne $expected ) {
            $self->set_error(
                "BadChecksum",
                field    => 'checksum',
                file     => $file,
                expected => $expected,
                actual   => $actual
            );
            push( @bad_files, "$file" );
        }

    }

    my $outcome;
    if (@bad_files) {
        $outcome = PREMIS::Outcome->new('warning');
        $outcome->add_file_list_detail( "files failed checksum validation",
            "failed", \@bad_files );
    }
    else {
        $outcome = PREMIS::Outcome->new('pass');
    }
    $volume->record_premis_event( 'page_md5_fixity', outcome => $outcome );
	$volume->record_premis_event( 'page_md5_create');

	return;
}

sub md5sum($) {
    my $file = shift;

    my $fh = new IO::File("<$file") or die("Can't open '$file': $!");
    $fh->binmode();

    return Digest::MD5->new->addfile($fh)->hexdigest;
    $fh->close();
}



1;


__END__
