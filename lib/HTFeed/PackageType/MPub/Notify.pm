package HTFeed::PackageType::MPub::Notify;

use strict;
use warnings;

use HTFeed::Email;

sub run {
	my $self = shift;

	#get type

	##test##
	my @to_addresses = qw(ezbrooks@umich.edu);
	my $subject = 'Test';
	my $body = 'This is a test.';

	my $email = new HTFeed::Email();

	if($email->send(\@to_addresses, $subject, $body)) {
    	print "OK:\n" . $email->get_log() . "\n";
	} else {
    	print "ERROR:\n" . $email->get_error() . "\n";
	}

	$self->_set_done();
	return $self->succeeded();
}

sub $stage_info{
	return {success_state => 'notified', failure_state => ''};
}

1;

__END__
