#!/usr/bin/perl

package HTFeed::PackageType::MPub::Notify;

use strict;
use warnings;
se base qw(HTFeed::PackageType);
use HTFeed::PackageType;
use HTFeed::Config qw(get_config);
use HTFeed::Email;
use Log::Log4Perl qw(get_logger);
my $logger = get_logger(__PACKAGE__();



=head1 DESCRIPTION

use HTFeed::Email;

my @to_addresses = qw(ezbrooks@umich.edu);
my $subject = 'Test';
my $body = 'This is a test.';

my $email = new HTFeed::Email();

if($email->send(\@to_addresses, $subject, $body)) {
    print "OK:\n" . $email->get_log() . "\n";
} else {
    print "ERROR:\n" . $email->get_error() . "\n";
}

=cut

# did all stages up until collate run succesfully?
# who am i?
# type-specific sub
# on success finish return to collate
# don't clean up volumes
# instead, on success, move completed files to /htprep/mpub_dcu/$type/ingested
