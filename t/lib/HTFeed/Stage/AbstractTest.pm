package HTFeed::Stage::AbstractTest;

use warnings;
use strict;

use base qw(HTFeed::Test::Class);
use Test::More;
use HTFeed::Test::Support qw(get_test_volume);
use HTFeed::StagingSetup;
use HTFeed::Config qw(get_config);

use File::Path qw(make_path);
use File::Find;

sub startup : Test(startup => 3){
    my $self = shift;
    my $t_class = $self->testing_class();
    
    # instantiate and make sure it isa what it should be
    my $volume = get_test_volume();
    my $obj = new_ok( $t_class => [volume => $volume] );
    isa_ok($obj, 'HTFeed::Stage', $t_class);
    
    # basic interface adherance
    can_ok($obj, qw(run set_error clean clean_success clean_failure clean_always clean_punt));
}

# make a clean stage for each test method
sub setup : Test(setup){
    my $self = shift;
    my $t_class = $self->testing_class();
    my $volume = get_test_volume($self->pkgtype);
    
    HTFeed::StagingSetup::make_stage;
    
    $self->{volume} = $volume;
    $self->{test_stage} = eval "$t_class->new(volume => \$volume)";
}

# eliminate junk left behind
sub stage_abstract_teardown : Test(teardown){
    HTFeed::StagingSetup::clear_stage;
}

sub clean_failure : Test(1){
    my $self = shift;
    my $test_stage = $self->{test_stage};
    
    $test_stage->force_failed_status(1);
    $self->place_artifacts();
    
    $self->look_for_artifacts(
        allowed => $self->allowed_artifacts_after_clean_failure(),
        required => $self->required_artifacts_after_clean_failure(),
        search_dirs => $self->all_staging_dirs(),
        event_name => "clean_failure",
    );
}

sub clean_success : Test(1){
    my $self = shift;
    my $test_stage = $self->{test_stage};
    
    $test_stage->force_failed_status(0);
    $self->place_artifacts();
    
    $self->look_for_artifacts(
        allowed => $self->allowed_artifacts_after_clean_success(),
        required => $self->required_artifacts_after_clean_success(),
        search_dirs => $self->all_staging_dirs(),
        event_name => "clean_success",
    );
}

=item

override this with a sample run of testing_class or use artifacts_to_place to let parent
place_artifacts automatically place artifacts

=cut
sub place_artifacts{
    my $self = shift;
    my $artifacts = $self->artifacts_to_place;
    
    foreach my $artifact (@{$artifacts}){

        $artifact =~ /(.*\/)(.*)/;
        my $path = $1;
        my $file = $2;

        make_path $path unless (-d $path);
        die "path $path not created" unless (-d $path);

        if ($file){
            `touch $artifact`;
            die "file $artifact not created" unless (-f $artifact);
        }
        
        note "$artifact created";
    }
}

sub look_for_artifacts{
    my $self = shift;
    my $arg_hash = {
        allowed => [],
        required => [],
        search_dirs => [],
        event_name => "event",
        @_,
    };
    my @allowed     = @{$arg_hash->{allowed}    };
    my @required    = @{$arg_hash->{required}   };
    my %required    = map { $_ => 0 } @required;
    my @search_dirs = @{$arg_hash->{search_dirs}};
    my $event_name  = $arg_hash->{event_name};

    # allow required artifacts
    push @allowed, @required;
    
    # look for artifacts
    my $unwanted_found = 0;
    find(sub{
            my $artifact = $File::Find::name;
            if (! -d $artifact){
                my $bad_file = 1;
                foreach my $re (@allowed){
                    if ($artifact =~ /$re/){
                        $bad_file = 0;
                        last;
                    }
                }
                if($bad_file){
                    $unwanted_found++;
                    diag("excess artifact after $event_name: $artifact");
                }
                foreach my $re (keys %required){
                    if ($artifact =~ /$re/){
                        $required{$re}++;
                    }
                }
            }
        }, @search_dirs
    );
    my $wanted_unfound = 0;
    foreach my $key (keys %required){
        $wanted_unfound++ unless $required{$key};
    }
    
    ok($unwanted_found == 0, "no excess artifacts after $event_name");
    ## commented out until we can find a use for it
    #ok($wanted_unfound == 0, "no missing artifacts after $event_name");
}

=item artifacts_to_place

override with array of items that testing_class should be expected to leave behind
directories should include trailing slash

=cut

sub artifacts_to_place{
    return [];
}

=item allowed/required artifacts

override with array of regex strings matching the files that you want to see

=cut

sub allowed_artifacts_after_clean_failure{
    return [];
}

sub required_artifacts_after_clean_failure{
    return [];
}

sub allowed_artifacts_after_clean_success{
    return [];
}

sub required_artifacts_after_clean_success{
    return [];
}

sub allowed_artifacts_after_clean_punt{
    return [];
}

sub required_artifacts_after_clean_punt{
    return [];
}


# return an arrayref conftaining the name of every staging dir
sub all_staging_dirs{
    my $staging = get_config('staging');
    ##my $disk_staging = get_config('staging'=>'disk');

    my $dirs = [];
    
    foreach my $key (keys %{$staging}){
        my $dir = $staging->{$key};
        push @{$dirs}, $dir unless (ref $dir);
    }
    
    return $dirs;
}

sub pkgtype{
    return undef;
}

1;

__END__
