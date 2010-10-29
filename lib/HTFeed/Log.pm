package HTFeed::Log;

# Loads HTFeed log support classes,
# initializes logging,
# contains logging helper methods

use warnings;
use strict;
use Carp;

use Data::Dumper;
$Data::Dumper::Indent = 0;

use Log::Log4perl;

use HTFeed::Log::Warp;
use HTFeed::Log::Layout::PrettyPrint;
use HTFeed::Config qw(get_config);

# list of acceptable error codes
my %error_codes = (
    NotMatchedValue     => 'Mismatched/invalid value for field',
    BadField            => 'Error extracting field',
    BadValue            => 'Invalid value for field',
    BadFilename         => 'Invalid filename',
    BadFilegroup        => 'File group is empty',
    MissingFile         => 'Missing file',
    BadChecksum         => 'Checksum error',
    BadUTF              => 'UTF-8 validation error',
    BadFile             => 'File validation failed',
    MissingField        => 'Missing field value',
    NotEqualValues      => 'Mismatched field values',
    FatalError          => 'Fatal error',
    DownloadFailed      => 'Download failed',
    FileMissing         => 'File missing',
    IncompleteStage     => 'Stage did not complete',
    DecryptionFailed    => 'GPG decryption failed',
);

# list of fields accepted in log hash
# these fields are allowed in any log event (error, debug, etc)
# as long as config.l4p runs it through one of our custom filters:
#   HTFeed::Log::Warp (for DB appenders), HTFeed::Log::Layout::PrettyPrint (for text appenders)
my @fields = qw(volume file field actual expected detail);

# call EXACTLY ONCE to initialize logging
sub init{
    # get log4perl config file
    my $l4p_config = get_config('l4p_config');

    Log::Log4perl->init($l4p_config);
    Log::Log4perl->get_logger(__PACKAGE__)->trace('l4p initialized');
    
    return;
}

# convert a hash containing keys in @fields to an array
# ordered like @fields, with undef where appropriate
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

# take a string that should be a key in %error_codes, return appropriate error string
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
