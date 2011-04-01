package HTFeed::Log;

# Loads HTFeed log support classes,
# initializes logging,
# contains logging helper methods

use warnings;
use strict;
use HTFeed::Config qw(get_config);
use Carp;

use Data::Dumper;
#$Data::Dumper::Indent = 0;

use Log::Log4perl;

use HTFeed::Log::Warp;
use HTFeed::Log::Layout::PrettyPrint;
use Sys::Hostname;

my $root_log_config = get_config('l4p' => 'root_logger');

# list of acceptable error codes
my %error_codes = (
    BadChecksum         => 'Checksum error',
    BadField            => 'Error extracting field',
    BadFile             => 'File validation failed',
    BadFilegroup        => 'File group empty or contains too many items',
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
    VolumePunted	=> 'Volume punted',
    RunStage		=> 'Running stage',
    UnexpectedError	=> 'Unexpected error',
    StageSucceeded	=> 'Stage succeeded',
    StageFailed		=> 'Stage failed',


);

# list of fields accepted in log hash
# these fields are allowed in any log event (error, debug, etc)
# as long as config.l4p runs it through one of our custom filters:
#   HTFeed::Log::Warp (for DB appenders), HTFeed::Log::Layout::PrettyPrint (for text appenders)
my @fields = qw(namespace objid file field actual expected detail operation stage);

# on import 
sub import{
    # init once and only once
    return if(Log::Log4perl->initialized());

    my $class = shift;
    my $config = shift;
    my $new_root_log_config = $config->{root_logger};
    if ($new_root_log_config){
        $root_log_config = $new_root_log_config;
    }
    _init();
}

# call to initialize logging
sub _init{
    # get log4perl config file
    my $l4p_config = get_config('l4p'=>'config');

    Log::Log4perl->init($l4p_config);
    Log::Log4perl->get_logger(__PACKAGE__)->trace('l4p initialized');

    return;
}

# change out file for file logger
# if this isn't set and we use the file logger everything is logged to /dev/null
# as per config.l4p
#
# set_logfile($filename)
sub set_logfile{
    my $file_name = shift;
    my $appender = Log::Log4perl::appender_by_name('file');
    $appender->file_switch($file_name);
    
    return;
}

# returns get_config('l4p' => 'root_logger')
# unless an override was set by
# use HTFeed::Log {root_logger => 'INFO, file'}
#
# should only be called by config.l4p
#
# get_root_log_config()
sub get_root_log_config{
    return $root_log_config;
}

# convert a hash containing keys in @fields to an array
# ordered like @fields, with undef where appropriate
sub fields_hash_to_array{
    my $hash = shift;
    my @ret = ();
    
    $hash->{hostname} = hostname;
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
    my $error_code = shift;

    if (my $error_message = $error_codes{$error_code}){
        return $error_message;
    }
    
    # we don't recognise the error code
    #return "Invalid error code: $error_code";
    return $error_code;
}

1;

__END__;
