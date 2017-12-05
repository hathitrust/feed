package HTFeed::Test::Support;

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT_OK = qw(get_test_volume get_fake_stage md5_dir test_config);

use HTFeed::Config qw(get_config set_config);
use HTFeed::Volume;
use HTFeed::TestVolume;
use HTFeed::Stage::Fake;
use Digest::MD5;
use FindBin;
use File::Find;
use Carp;

my %staging_configs = (
    damaged     => {
        download  => get_config('test_staging','damaged') . '/download',
        ingest  => get_config('test_staging','damaged') . '/ingest',
        preingest  => get_config('test_staging','damaged') . '/preingest',
    },
    undamaged     => {
        download  => get_config('test_staging','undamaged') . '/download',
        ingest  => get_config('test_staging','undamaged') . '/ingest',
        preingest  => get_config('test_staging','undamaged') . '/preingest',
    },
    
    original    => {
        download  => get_config('staging'=>'download'),
        ingest    => get_config('staging'=>'ingest'),
        preingest => get_config('staging'=>'preingest'),
    },
);

sub test_config{
	my $test_type = shift;
	
	die("Unknown config $test_type") unless $staging_configs{$test_type};

    my $staging_config = $staging_configs{$test_type};
    
    foreach my $key (keys %{$staging_config}){
        my $value = $staging_config->{$key};
        set_config($value,'staging',$key);
    }
}

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
sub get_test_volume{
    my $voltype = shift;

    #TODO this should always be defined as some packagetype
    return HTFeed::TestVolume->new(objid => 'test', namespace => 'test', packagetype=> 'ht')
      if not defined $voltype or $voltype eq 'default';

    my $volumes = {
        google => {objid =>  '35112102255959',namespace => 'mdp',packagetype => 'google' },
        ia => {objid =>  'ark:/13960/t00000431',namespace => 'uc2',packagetype => 'ia' },
        yale => {objid =>  '39002001567222',namespace => 'yale',packagetype => 'yale' },
    };

    die("Unknown pkgtype $voltype") if not defined $volumes->{$voltype};

    return HTFeed::Volume->new(%{ $volumes->{$voltype} });
}

sub get_fake_stage{
    my $volume = get_test_volume();
    return HTFeed::Stage::Fake->new(volume => $volume);
}

# # md5_dir($directory)
# # returns an md5 sum for the contents of a directory
# # probably won't work on a non flat heirarchy
# sub md5_dir{
#     my $dir = shift;
# 
#     my $digest = Digest::MD5->new();
#     opendir(my $dirh, $dir) or die("Can't open $dir: $!");
#     my @files = ();
#     while(my $filename = readdir($dirh)) {
#         next if $filename eq '.' or $filename eq '..';
#         push(@files,$filename);
#     }
#     closedir($dirh);
# 
#     foreach my $file (sort @files){
#         $file = "$dir/$file";
#         open(my $fh, '<', $file);
#         binmode $fh;
#         eval{$digest->addfile($fh);};
#             if($@){confess "md5_dir: reading $dir/$file failed";}
#         close $fh;
#     }
#     
#     return $digest->hexdigest();
# }

sub get_test_classes{
    return \@test_classes;
}

1;

__END__
