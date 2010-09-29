package HTFeed::Exceptions;

use warnings;
use strict;
use Exporter 'import';

our @EXPORT_OK = qw(throw_validator_exception throw_fetch_exception);

##  TODO: This is not currently used, but will likely be useful when we begin implimenting the supervisor/stage runner

use Exception::Class (
    'HTFeed::Exception' => {
		description	=> 'Error in running ingest',
		fields		=> [ 'volume', 'file' ],
	},

    'HTFeed::Exception::Validator' => {
		isa			=> 'HTFeed::Exception',
		description => 'Fatal error in validation',
    	alias		=> 'throw_validator_exception',
	},

    'HTFeed::Exception::Fetch' => {
        isa         => 'HTFeed::Exception',
        description => 'Fatal error in fetching',
    	alias		=> 'throw_fetch_exception',
	},
);


1;

__END__;
