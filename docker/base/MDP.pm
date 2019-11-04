package HTFeed::Namespace::MDP;

use strict;
use warnings;
use HTFeed::Namespace ;
use HTFeed::XPathValidator qw(:closures);
use base qw(HTFeed::Namespace);

# The HathiTrust namespace
our $identifier = 'mdp';

our $config = {

    packagetypes => [qw(ht audio vendoraudio bentleyaudio)],

    description => 'University of Michigan (Barcoded material)',

    handle_prefix => '2027/mdp',

    validation => {
      'HTFeed::ModuleValidator::JPEG2000_hul' => {
          'layers' => v_eq( 'codingStyleDefault', 'layers', '8' ),
      }
    },
	
    tags => [qw(cic bib report)]

};


# Expected barcodes: 39015NNNNNNNN
# Some Bentley barcodes are broken in a predictable but very unusual way, see
# below.

sub validate_barcode {
    my $self    = shift;
    my $barcode = shift;
    return(
	   $self->luhn_is_valid( '35112', $barcode) or # Law 
	   $self->luhn_is_valid( '35128', $barcode) or # Kresge
	   $self->luhn_is_valid( '39015', $barcode) or # Ann Arbor
	   $self->luhn_is_valid( '39076', $barcode) or # Dearborn
	   $self->luhn_is_valid( '49015', $barcode) or # Flint
	   $self->luhn_is_valid( '69015', $barcode) or # Clements

      # Check for broken Bentley barcodes. Don't ask why they validate by
      # replacing the first 4 (yes, 4) characters with 80840 -- they just do.
      # Call it "Vendor Error."

      (     $barcode >= 39015071603500
        and $barcode <= 39015072100009
        and Algorithm::LUHN::is_valid( '80840' . substr( $barcode, 4 ) ) ) );
}

1;
__END__

=pod

This is the namespace configuration file for the University of Michigan.

=head1 SYNOPSIS

use HTFeed::Namespace;

my $namespace = new HTFeed::Namespace('mdp');

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2010 University of Michigan. All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut
