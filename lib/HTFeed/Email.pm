package HTFeed::Email;

use strict;
use warnings;
use HTFeed::Config qw(get_config);
use Mail::Sendmail;
use Mail::Mailer;
use MIME::Base64;

=head1 NAME

HTFeed::Email

=head1 SYNOPSIS

use HTFeed::Email;

#No ' or " around email addresses

my @to_addresses = qw(username@host.com anotheruser@lib.edu);

my $subject = 'Test';

my $body = 'This is a test';

my $email = new HTFeed::Email();

if($email->send(\@to_addresses, $subject, $body)) {

	print "OK:\n" . $email->get_log() . "\n";

}

else {

	print "ERROR:\n" . $email->get_error() . "\n";

}


=head1 DESCRIPTION

Send HTFeed error/reporting emails from get_config('from_email') using Mail::Sendmail.

This package uses 'localhost' as the mail server (the default for Mail::Sendmail).

A note about security: In case you're wondering, Mail::Sendmail does *not* use
Unix 'sendmail', so don't worry if you read about recent sendmail security
holes... Mail::Sendmail just communicates directly with the mail server through
sockets.

=head1 CONSTRUCTOR

=over 8

=item new

Constructor

=cut

sub new {
	my $package = shift;

	my $self = {};

	bless($self, $package);

	return $self;
}



=head1 METHODS


=item send ($to_addresses, $subject_text, $body_text, $cc)

Send a message to the email addresses in $to_addresses with the subject $subject_text and message body $body_text.

$to_addresses can be a single string or a reference to an array of email addresses.

$cc is an optional parameter and can also be a single string or a reference to an array.

=cut

sub send {
	my $self = shift;
	my $to = shift;
	my $subject = shift;
	my $body = shift;
	my $cc = shift;  # optional

	if(! defined($to)
	   || ! defined($subject)
	   || ! defined($body)) {

		return;
	}
	
	my $addresses = '';
	if(ref($to)) {
		$addresses .= join(',', @$to);
	}
	else {
		$addresses = $to;
	}

	my %msg = (To => "$addresses",
		   From => get_config('from_email'),
		   Subject => $subject,
		   Body => $body
		  );

	if(defined $cc) {
		if(ref($cc)) {
			$msg{'Cc'} = join(',', @$cc);
		}
		else {
			$msg{'Cc'} = $cc;
		}
	}

	if(! sendmail(%msg)) {
		
		$$self{'error'} = $Mail::Sendmail::error;

		return;
	}

	$$self{'log'} = $Mail::Sendmail::log;

	return 1;
}



sub send_excel_attach {
	my $self = shift;
	my $to = shift;
	my $subject = shift;
	my $msg = shift;
	my $cc = shift; # optional
	my $attachment = shift; # optional

	if(! defined($to) ||
	   ! defined($subject) ||
	   ! defined($msg)) {

		return;
	}

	my $admin_email = get_config('admin_email');

	my $addresses = '';
	if(ref($to)) {
		$addresses .= join(',', @$to);
	}
	else {
		$addresses = $to;
	}

	my @files_to_attach = ();
	if(ref($attachment)) {
		@files_to_attach = @$attachment;
	}
	else {
		push @files_to_attach, $attachment;
	}

	my $mailer = new Mail::Mailer('sendmail');

	my $body = "$msg\n";

	my %headers = ('To' => $addresses,
		       'From' => $admin_email,
		       'Subject' => $subject);

	if($cc) {
		$headers{'Cc'} = $cc;
	}

	if(@files_to_attach) {
		my $boundary = '====' . time() . '====';

		$headers{'Content-Type'} = "multipart/mixed; boundary=\"$boundary\"";

		my @attachment_content = ();

		foreach my $file (@files_to_attach) {
			open(IN, $file) or die($!);
			binmode IN;
			undef $/; # input record separator -
			# set to undef so <IN> will read everything to the end
			# of the file.
			push @attachment_content, encode_base64(<IN>);
			close(IN);
		}
					
		$boundary = '--'.$boundary;
		
		$body .= <<END;
$boundary
Content-Type: text/plain; charset="iso-8859-1"
Content-Transfer-Encoding: quoted-printable

$body

END

		for(my $c=0; $c<@files_to_attach; $c++) {
			
			my $file = $files_to_attach[$c];
			$file =~ s/(.*\/)//;
				
			$body .= <<END;
$boundary
Content-Type: application/vnd.ms-excel; name="$file"
Content-Transfer-Encoding: base64
Content-Disposition: attachment; filename="$file"

$attachment_content[$c]
END
		}

		$body .= "$boundary--";
		
		# Delete files after they've been sent
		#foreach (@files_to_attach) {
		#	`rm $_`;
		#}
	}

	$mailer->open(\%headers);

	print $mailer($body);

	$mailer->close;

	return 1;
}



=item get_error

Return error from last failed Mail::Sendmail::sendmail() call.

=cut

sub get_error {
	my $self = shift;

	if(defined($$self{'error'})) {
		
		return($$self{'error'});
	
	}
	
	else {

		return;
	
	}
}



=item get_log

Return log text from last successful Mail::Sendmail::sendmail() call.

=cut

sub get_log {
	my $self = shift;

	if(defined($$self{'log'})) {
		
		return($$self{'log'});

	}

	else {
		return;

	}
}



1;

__END__

=head1 AUTHOR

Aaron Elkiss, University of Michigan, aelkiss@umich.edu

=head1 COPYRIGHT

Copyright (c) 2006-2010 University of Michigan. All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

