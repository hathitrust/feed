package HTFeed::Log;

# Loads HTFeed log support classes and initializes logging

use warnings;
use strict;
use Carp;

use Data::Dumper;
$Data::Dumper::Indent = 0;

use HTFeed::Log::Warp;
use HTFeed::Log::Layout::PrettyPrint;

use Log::Log4perl;

# list of acceptable error codes
my %error_codes = (
    NotMatchedValue     => "Mismatched/invalid value for field",
    BadField            => "Error extracting field",
    BadValue            => "Invalid value for field",
    BadFilename         => "Invalid filename",
    BadFilegroup        => "File group is empty",
    MissingFile         => "Missing file",
    BadChecksum         => "Checksum error",
    BadUTF              => "UTF-8 validation error",
    BadFile             => "File validation failed",
    MissingField        => "Missing field value",
    NotEqualValues      => "Mismatched field values",
    FatalError          => "Fatal error",
);

# list of fields accepted in error hash
my @fields = qw(volume file field actual expected detail);

sub init{
    # check for / read environment var
    my $l4p_config;
    if (defined $ENV{HTFEED_L4P}){
        $l4p_config = $ENV{HTFEED_L4P};
    }
    else{
        croak print "set HTFEED_L4P\n";
    }

    Log::Log4perl->init($l4p_config);
    Log::Log4perl->get_logger(__PACKAGE__)->trace("l4p initialized");
    
    return;
}

sub fields_hash_to_array{
    # get rid of package name
    shift;
    my $hash = shift;
    my @ret = ();
    
    foreach my $field (@fields){
        # handle populated field
        if (my $entry = $hash->{$field}){
            # handle scalar field
            if (! ref($entry)){
                push @ret, $entry;
            }
            # handle fields with data
            else{
                push @ret, Dumper($entry);
            }
        }
        # handle empty field
        else{
            push @ret, "";
        }
    }
    return \@ret;
}

sub error_code_to_string{
    # get rid of package name
    shift;
    
    my $error_code = shift;
    if (my $error_message = $error_codes{$error_code}){
        return $error_message;
    }
    
    # we don't recognise the error code
    return "Invalid error code: $error_code";
}

1;

__END__;
