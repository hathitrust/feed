#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../../lib";

use HTFeed::Log { root_logger => 'INFO, dbi' };
use Log::Log4perl qw(get_logger);

#use HTFeed::StagingSetup;
use HTFeed::Version;

#use HTFeed::Dataset;
use HTFeed::Dataset::RightsDB;
use HTFeed::Volume;
use HTFeed::PackageType::HathiTrust::Volume;
use HTFeed::Config;
use HTFeed::RunLite qw(runlite);

my $pid = $$;

# get volume list
my $volumes = get_volumes(get_config('dataset'=>'full_set_rights_query'));

HTFeed::PackageType::HathiTrust::Volume::set_stage_map(['HTFeed::Dataset::Stage::UnpackText',
                                                        'HTFeed::Dataset::Stage::Pack',
                                                        'HTFeed::Dataset::Stage::Collate']);
runlite( volumes => $volumes,
         logger => 'HTFeed::Dataset',
         verbose => 1);

__END__

=head1 NAME

    generate_base_set.pl - generate base dataset

=head1 Usage

generate_base_set.pl

=cut

