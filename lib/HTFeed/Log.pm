package HTFeed::Log;

use warnings;
use strict;
use HTFeed::Config qw(get_config);
use Carp;
use Getopt::Long qw(:config pass_through no_ignore_case no_auto_abbrev);
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
    Disallowed          => 'Not allowed to be queued (on disallow list)',
    OperationFailed     => 'Operation failed',
    FatalError          => 'Fatal error',
    GRINError           => 'GRIN could not convert book',
    IncompleteStage     => 'Stage did not complete',
    MissingField        => 'Missing field value',
    MissingFile         => 'Missing file',
    NotEqualValues      => 'Mismatched field values',
    NotMatchedValue     => 'Mismatched/invalid value for field',
    NoBibData           => 'Missing bibliographic data',
    ToolVersionError	=> 'Can\'t get tool version',
    VolumePunted	    => 'Volume punted',
    RunStage		    => 'Running stage',
    UnexpectedError	    => 'Unexpected error',
    StageSucceeded	    => 'Stage succeeded',
    StageFailed		    => 'Stage failed',


);

# list of fields accepted in log hash
# these fields are allowed in any log event (error, debug, etc)
# as long as config.l4p runs it through one of our custom filters:
#   HTFeed::Log::Warp (for DB appenders), HTFeed::Log::Layout::PrettyPrint (for text appenders)
my @fields = qw(namespace objid file field actual expected detail operation stage);

# on import
my $log_initialized = 0;

sub import{
    # init once and only once
    return if($log_initialized);
    $log_initialized = 1;

    my $class = shift;
    my $config = shift;
    
    # override config command option
    my $root_log_config_from_command;
    my ($level, $screen, $dbi, $file);
    GetOptions (
        "level=s" => \$level,
        "screen"  => \$screen,
        "dbi"     => \$dbi,
        "file=s"  => \$file
    );
    
    if ($level or $screen or $dbi or $file){
        $level = 'INFO' unless $level; # default to INFO when using a logger flag
        die "Invalid logging options: please specify logger"
            unless($screen or $dbi or $file);
        
        $root_log_config_from_command = $level;
        $root_log_config_from_command .= ', dbi' if ($dbi);
        $root_log_config_from_command .= ', screen' if ($screen);
        $root_log_config_from_command .= ', file' if ($file);
    }

    # override config use option
    my $root_log_config_from_use = $config->{root_logger};

    # set logging config
    # command takes precedence over use, which takes precedence over config file
    
    # $root_log_config
    if ($root_log_config_from_command){
        $root_log_config = $root_log_config_from_command;
    }
    elsif ($root_log_config_from_use){
        $root_log_config = $root_log_config_from_use;
    }
    
#    print "Logging with root logger config '$root_log_config'\n";
    _init();

    # log file
    set_logfile($file) if $file;
}

# call to initialize logging
sub _init{
    # get log4perl config file
    my $l4p_config = get_config('l4p'=>'config');

    Log::Log4perl->init($l4p_config);
    Log::Log4perl->get_logger()->trace('l4p initialized');

    return;
}

# set_logfile($filename)
# change out file for file logger
# if this isn't set and we use the file logger everything is logged to /dev/null as per config.l4p
sub set_logfile{
    my $file_name = shift;
    my $appender = Log::Log4perl::appender_by_name('file');
    $appender->file_switch($file_name);
    
    return;
}

# returns get_config('l4p' => 'root_logger')
# unless Log.pm was instructed to override this on import (see pod)
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

__END__

=head1 NAME

HTFeed::Log - Logging for HTFeed

=head1 SYNOPSIS

Loads HTFeed log support classes and initializes logging.
HTFeed::Log contains various logging helper methods.

=head1 DESCRIPTION

Initialize Log4perl with default config (from config.yaml)
use HTFeed::Log;

Initialize Log4perl with custom root logger (use)
use HTFeed::Log {root_logger => 'INFO, screen'};

Initialize Log4perl with custom root logger (command line)
while executing any script that uses Log.pm (even indirectly)
myscript.pl [-screen] [-dbi] [-file FILENAME] [-level (TRACE|DEBUG|INFO|WARN|ERROR|FATAL|OFF)]

=cut
