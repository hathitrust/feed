package HTFeed::PackageType::IslamicManuscripts;
use HTFeed::PackageType;
use base qw(HTFeed::PackageType::MPub);
use strict;

our $identifier = 'islam';

our $config = {
    %{$HTFeed::PackageType::MPub::config},
    required_filegroups => [qw(image)],
};

1;

__END__
