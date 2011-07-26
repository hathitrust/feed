package HTFeed::PackageType::MPubDCU::UMP;

use warnings;
use strict;
use base qw(HTFeed::PackageType::MPubDCU);

#base case for MPubDCU (UM Press)

our $identifier = 'ump2ht';

our $config = {
    %{$HTFeed::PackageType::MPubDCU::config},
    description => 'University of Michigan Press',
    capture_agent => 'MPublishing',
    
    # Regular expression that distinguishes valid files in the file package
    # UM Press material may include a PDF. TBD how to represent this.
    valid_file_pattern => qr/^( 
		checksum\.md5 |
		pageview\.dat |
		\w+\.pdf |
		\d{8}.(jp2|tif|txt)
		)/x,

    # See HTFeed::PackageType for documentation
    filegroups => {
        image => {
            prefix => 'IMG',
            use => 'image',
            file_pattern => qr/\d{8}\.(jp2|tif)$/,
            required => 1,
            content => 1,
            jhove => 1,
            utf8 => 0
        },
        ocr => {
            prefix => 'OCR',
            use => 'ocr',
            file_pattern => qr/\d{8}\.txt$/,
            required => 1,
            content => 1,
            jhove => 0,
            utf8 => 1
        },
        pdf => {
            prefix => 'PDF',
            use => 'pdf',
            file_pattern => qr/\d{8}\.pdf$/,
            required => 0,
            content => 1,
            jhove => 0,
            utf8 => 0
        },
    },

    # Validation overrides - make/model not expected
    validation => {
        'HTFeed::ModuleValidator::JPEG2000_hul' => {
            'camera'               => undef,
        }
    },

};

__END__

=pod

This is the package type configuration file for base case MPubDCU materials
Specifically UM Press

=head1 SYNOPSIS

use HTFeed::PackageType;

my $pkgtype = new HTFeed::PackageType('ump2ht');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
