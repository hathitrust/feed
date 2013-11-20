package HTFeed::Log::Layout::HTML;

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;
use Data::Dumper;

# A Log::Log4perl::Layout
# requires log4perl.appender.app_name.warp_message = 0

#no strict qw(refs);
use base qw(Log::Log4perl::Layout);

sub new {
    my $class = shift;
    $class = ref ($class) || $class;

    my $self = {
        format      => undef,
        info_needed => {},
        stack       => [],
    };

    bless $self, $class;
    return $self;
}

sub render {
    my($self, $message, $category, $priority, $caller_level) = @_;
    
    my $error_message;

    # transform ("ErrorCode",field => "data",...) if $message has 2+ fields
    if ($#$message){    
        my $error_code = shift @$message;
        my $error_expanded = HTFeed::Log::error_code_to_string($error_code);
        my %fields = ( @$message );
        # irrelevant fields
        delete $fields{file};
        delete $fields{objid};
        delete $fields{namespace};
        delete $fields{stage};

        if($error_code eq 'BadFile') {
            $error_message = "<p>$error_expanded. Check the above messages to see if the errors can be remediated.</p>";
        } elsif(grep {$error_code eq $_} qw(BadField BadValue MissingField NotEqualFields NotMatchedValue)) {
            $error_message = "<p>";
            $error_message .= process_remediable(\%fields);
            $error_message .= process_message($error_code,$error_expanded,\%fields);
            $error_message .= process_detail(\%fields);
            $error_message .= process_expected(\%fields);
            $error_message .= "</p>";
        } elsif($error_code eq 'Validation failed') {
            # validator failed - might validate multiple fields
        } else {
            # unknown error
            $error_message = "<p>";
            if($priority eq 'WARN' or $priority eq 'ERROR') {
                $error_message .= "Something unexpected happened: ";
            }
            $error_message .= " $error_expanded\n";
            $error_message .= "<table>\n";
            foreach my $key (sort keys(%fields)) {
                my $val = $fields{$key};
                # handle fields with data
                if (ref($val)){
                    $val = Dumper($val);
                }
                if(not defined $val) {
                    $val = '(null)';
                } 
                if($val eq '') {
                    $val = "(empty)";
                }
                $error_message .= "<tr><td>$key</td><td>$val</td></tr>";
            }
            $error_message .= "</table></p>\n";
        }

    
    }
    # just print the message as is
    elsif ($priority eq 'ERROR' or $priority eq 'WARN') {
        $error_message = "<p><b>Something unexpected happened:</b> " . shift(@$message) . "</p>";
    } else {
        $error_message = "<p>" . shift(@$message) . "</p>";
    }
    
    return $error_message;
}

sub process_detail {
    my $fields = shift;
    my $error_message = "";
    if($fields->{detail}) {
        $error_message .= ": $fields->{detail}; ";
    }  else {
        $error_message .= ": ";
    }
    return $error_message;
}

sub process_message {
    my $error_code = shift;
    my $error_expanded = shift;
    my $fields = shift;

    return "$error_expanded $fields->{field}";
}

sub process_expected {
    my $fields = shift;
    my $error_message = "";

    if(defined $fields->{expected}) {
        $error_message .= "expected <tt>$fields->{expected}</tt>; ";
    }
    if(defined $fields->{actual}) {
        $error_message .= "saw <tt>$fields->{actual}</tt>.";
    }
    return $error_message;
}

sub process_remediable {
    my $fields = shift;
    if($fields->{remediable}) {
        return '<span style="color:#e6cb1b; font-weight:bold">Remediable:</span> ';
    } else {
        return '<span style="color:#E3001E; font-weight:bold">Nonremediable:</span> ';
    }
}

1;

__END__;
