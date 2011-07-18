package HTFeed::Dataset;

use warnings;
use strict;

use File::Copy;
use HTFeed::Config;
use HTFeed::Stage::Unpack qw(unzip_file);

use File::Copy;
use File::Pairtree;
use File::Path qw(make_path);

=item add_volume

=cut
sub add_volume{
    my $volume = shift;
    my $htid = $volume->get_identifier;

    die "AIP not in repository for $htid"
        unless (-e $volume->get_repository_zip_path() and -e $volume->get_repository_mets_path());

    # extract all .txt
    unzip_file(_make_self(),$volume->get_repository_zip_path(),$volume->get_staging_directory(),'*.txt');
        
    # make sure list of files extracted matches list of files expected
    my $expected = $volume->get_file_groups()->{ocr}->{files};
    # WARNING: get_all_directory_files memoizes its data, don't rely on it more than once if the staging dir contents may have changed
    my $found = $volume->get_all_directory_files;
    
    # compare found and expected
    my @missing; # @expected - @found # fatal error if non empty
    my @extra;   # @found - @expected # items in this array will be deleted from fs
    {
        my %found = map {$_ => 1} @{$found};
        my %expected =  map {$_ => 1} @{$expected};

        foreach my $e (keys %found){ push @extra, $e unless($expected{$e}) };
        foreach my $e (keys %expected){ push @missing, $e unless($found{$e}) };
    }
    
    # missing files is a fatal error
    die join (q(,), @missing) . ' files missing' if ($#missing > -1);

    # delete any .txt files that aren't ocr
    foreach my $extra_file (@extra){
        unlink get_config('staging'=>'ingest') . "/$extra_file";
    }

    # pack
    my $pack = HTFeed::Stage::Pack->new(volume => $volume);
    $pack->run();
    $pack->clean();
    die "packing failed" if ($pack->failed);
    
    # collate
    make_path $volume->get_dataset_path;
    copy $volume->get_repository_mets_path(), $volume->get_dataset_path();
    copy $volume->get_zip_path(), $volume->get_dataset_path();

    # clean
    $volume->clean_unpacked_object;
    $volume->clean_zip;
}

# don't instantiate externally, this is just to pass around to make $self->set_error() work
sub _make_self{
    my $self = bless {failed => 0}, __PACKAGE__;
    return $self;
}

sub set_error{
    HTFeed::Stage::set_error(@_);
}

#=item remove_volume
#
#=cut
#sub remove_volume{
#    my $volume = shift;
#    
#}

1;

__END__

