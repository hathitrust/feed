package HTFeed::Log;

# Loads HTFeed log support classes,
# initializes logging,
# contains logging helper methods

use warnings;
use strict;
use HTFeed::Config qw(get_config);
use Carp;

use Data::Dumper;
$Data::Dumper::Indent = 0;

use Log::Log4perl;

use HTFeed::Log::Warp;
use HTFeed::Log::Layout::PrettyPrint;

use Log::Log4perl;


# list of acceptable error codes
my %error_codes = (
    BadChecksum         => 'Checksum error',
    BadField            => 'Error extracting field',
    BadFile             => 'File validation failed',
    BadFilegroup        => 'File group is empty',
    BadFilename         => 'Invalid filename',
    BadUTF              => 'UTF-8 validation error',
    BadValue            => 'Invalid value for field',
    OperationFailed     => 'Operation failed',
    FatalError          => 'Fatal error',
    IncompleteStage     => 'Stage did not complete',
    MissingField        => 'Missing field value',
    MissingFile         => 'Missing file',
    NotEqualValues      => 'Mismatched field values',
    NotMatchedValue     => 'Mismatched/invalid value for field',
    ToolVersionError	=> 'Can\'t get tool version',
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
