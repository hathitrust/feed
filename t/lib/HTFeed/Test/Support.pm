package HTFeed::Test::Support;

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT_OK = qw(get_test_volume get_fake_stage md5_dir);

use HTFeed::Volume;
use HTFeed::Stage::Fake;
use Digest::MD5;
use FindBin;
use File::Find;

use HTFeed::Config qw(set_config);
set_config('/htapps/test.babel/feed/t/staging/download','staging'=>'download');
set_config('/htapps/test.babel/feed/t/staging/ingest','staging'=>'ingest');

## TODO: use a flag to determine if/when test_classes are loaded
my @test_classes;
{
    my $libDir = "$FindBin::Bin/lib/";
    # get the path to each test classes
    find(sub{
            if (-f and $_ =~ /^Test\.pm$/ ){
                my $name = $File::Find::name;
                $name =~ s/$libDir//;
                push @test_classes, $name;
            }
        }, $libDir
    );
        
    # require all test classes
    foreach my $class ( @test_classes ){
        require $class;
    }

    # convert @test_classes from paths to package names
    foreach my $i ( 0..$#test_classes ){
        $test_classes[$i] =~ s/\//::/g;
        $test_classes[$i] =~ s/\.pm$//;        
    }
}

# get_test_volume
# returns a valid volume object
## TODO: add options for ns, packagetype
## TODO: get pt, ns, objid from a config file
sub get_test_volume{
    return HTFeed::Volume->new(objid => '35112102255959',namespace => 'mdp',packagetype => 'google');
}

sub get_fake_stage{
    my $volume = get_test_volume();
    return HTFeed::Stage::Fake->new(volume => $volume);
}

# md5_dir($directory)
# returns an md5 sum for the contents of a directory
# probably won't work on a non flat heirarchy
sub md5_dir{
    my $dir = shift;

    my $digest = Digest::MD5->new();
    my @ls = split /\s/, `ls $dir`;

    foreach my $file (@ls){
        $file = "$dir/$file";
        open(my $fh, '<', $file);
        binmode $fh;
        $digest->addfile($fh);
        close $fh;
    }
    
    return $digest->hexdigest();
}

sub get_test_classes{
    return \@test_classes;
}

1;

__END__
