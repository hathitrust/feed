#!/usr/bin/perl

package HTFeed::PackageType::DLXS::VolumeValidator;

use base qw(HTFeed::VolumeValidator);
use File::Basename;
use HTFeed::XMLNamespaces qw(register_namespaces);
use Log::Log4perl qw(get_logger);

use strict;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    if($self->{volume}->should_check_validator('missing_files')) {
        $self->{stages}{validate_consistency} =  \&_validate_consistency;
    } else {
        delete $self->{stages}{validate_consistency};
    }

    return $self;

}

sub _validate_consistency {
    my $self   = shift;
    $self->SUPER::_validate_consistency(@_);

    my $volume = $self->{volume};

    my $files = $volume->get_required_sequence_file_groups_by_page();

    # query PREMIS events for item to make sure any sequence gaps are listed there:
    # <HT:fileList xmlns:HT="http://www.hathitrust.org/premis_extension"
    # status="removed"><HT:file>00000001.tif</HT:file><HT:file>00000001.txt</HT:file></HT:fileList>
    my $mets_xpc = $volume->get_source_mets_xpc();
    my @allowed_missing_seq = map { basename($_->toString(),".txt",".tif",".jp2") } 
        $mets_xpc->findnodes("//htpremis:fileList[\@status='removed']/htpremis:file/text()");

    my $prev_sequence_number = 0;
    my @sequence_numbers     = sort( keys(%$files) );
    foreach my $sequence_number (@sequence_numbers) {
        for(my $i = $prev_sequence_number + 1; $i < $sequence_number; $i++) {
                # anything in this range is missing
                if( ! grep { $_ == $i } @allowed_missing_seq ) {
                $self->set_error( "MissingFile",
                    detail =>
                    "Skip sequence number from $prev_sequence_number to $sequence_number"
                );
            }
        }
        $prev_sequence_number = $sequence_number;
    }

    # Make sure that every jp2 has a corresponding TIFF.
    while ( my ( $sequence_number, $files ) = each( %{$files} ) ) {
        my $has_jp2 = 0;
        my $has_tif = 0;
        foreach my $file (@{$files->{image}}) {
            $has_jp2++ if($file =~ /\.jp2$/);
            $has_tif++ if($file =~ /\.tif$/);
        }
        if($has_jp2 and !$has_tif) {
            $self->set_error("MissingFile",file => "$sequence_number.tif",
                detail => "JP2 for seq=$sequence_number exists but TIFF does not.")
        }
    }
}

sub run {
    my $self = shift;
    my $volume = $self->{volume};

    # Run each enabled stage
    foreach my $stage ( @{$self->{run_stages}} ) {
        if ( exists( $self->{stages}{$stage} ) ) {
            my $sub = $self->{stages}{$stage};
            get_logger()->debug("Running validation stage $stage");
            &{$sub}($self);

        }
        else {
            croak("Undefined validation stage $stage requested");
        }
    }

    # do this last
    $self->_set_done();
    if ( !$self->failed() ) {
        my $outcome = PREMIS::Outcome->new('pass');
        my @skip_validation = @{$volume->get_nspkg()->get('skip_validation')};
        my $skip_validation_note = $volume->get_nspkg()->get('skip_validation_note');
        if(@skip_validation) {
            $outcome->add_detail_note($skip_validation_note . "\nThe following validation checks were skipped: " . join(', ', @skip_validation) . ".");
        }
        $self->{volume}->record_premis_event( 'package_validation',
            outcome => $outcome );
            
    }

    return;
}


1;
