package HTFeed::PackageType::Google::Download::Test;

use warnings;
use strict;

use base qw(HTFeed::Stage::AbstractTest);
use Test::More;
use HTFeed::Config;

sub artifacts_to_place{
    return [
        get_config('staging'=>'download') . '/39015000275118.tar.gz.gpg'
    ];
}

sub required_artifacts_after_clean_success{
    return artifacts_to_place();
}

1;

__END__
