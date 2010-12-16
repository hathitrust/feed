package HTFeed::Stage;

# abstract class, children must impliment following methods:
# run
# children may also override clean_* methods as needed

use warnings;
use strict;
use Carp;
use File::Path qw(remove_tree);
use Log::Log4perl qw(get_logger);
use HTFeed::Config qw(get_config);

use base qw(HTFeed::SuccessOrFailure);

sub new{
	my $class = shift;

	# make sure we are instantiating a child class, not self
	if ($class eq __PACKAGE__){
		croak __PACKAGE__ . ' can only construct subclass objects';
	}
		
	my $self = {
		volume  => undef,
		@_,
		has_run => 0,
		failed  => 0,
	};
	
	unless ($self->{volume} && $self->{volume}->isa("HTFeed::Volume")){
		croak "$class cannot be constructed without an HTFeed::Volume";
	}

	bless ($self, $class);
	return $self;
}

# returns information about the stage
# to support this children should impliment stage_info() that returns a hash ref like:
#   {success_state => 'validated', failure_state => 'punted'};
#
# synopsis
# my $info_hash = $stage->get_stage_info();
# my $info_item = $stage->get_stage_info('item_name');
sub get_stage_info{
    my $self = shift;
    my $field = shift;
    
    if ($field){
        return $self->stage_info()->{$field};
    }
    return $self->stage_info();
}

# abstract
# sub run{}

sub _set_done{
	my $self = shift;
	$self->{has_run}++;
	return $self->{has_run};
}

# Return true if failed, false if succeeded
# Set error and return true if ! $self->{has_run}
sub failed{
	my $self = shift;
	return $self->{failed} if $self->{has_run};
	$self->set_error('IncompleteStage',detail => ref($self));
	return 1;
}

# set fail, log errors
sub set_error{
	my $self = shift;
	my $error = shift;
	$self->{failed}++;

	# log error w/ l4p
	my $logger = get_logger(ref($self));
	$logger->error($error,volume => $self->{volume}->get_objid(),@_);
}

# log info message
sub set_info{
    my $self = shift;
    my $message = shift;
    
    my $logger = get_logger(ref($self));
    $logger->info('Info',detail => $message,volume => $self->{volume}->get_objid(),@_);
}

# run this to do appropriate cleaning after run()
# this generally should not be overriden,
# instead override clean_success() and clean_failure()
sub clean{
    my $self = shift;
    my $success = $self->succeeded();
    
    if ($success){
        $self->clean_success();
    }else{
        $self->clean_failure();
    }
    
    $self->clean_always();
}

# do cleaning that is appropriate after success
# run automatically by clean() when needed
sub clean_success{
    return;
}

# do cleaning that is appropriate after failure
# run automatically by clean() when needed
sub clean_failure{
    return;
}

# do cleaning independent of success
# run automatically by clean() when needed
sub clean_always{
    return;
}

# cleaning to do on punt
# NOT run by clean(), because clean() doesn't know you punted
sub clean_punt{
    return;
}

# unlink download from ram staging
#sub clean_ram_download{
#    my $self = shift;
#    my $volume = $self->{volume};
#    my $download_to_disk = $volume->get_nspkg()->get('download_to_disk');
#    
#    if(! $download_to_disk){
#        my $path = get_config('staging'=>'memory');
#        my $file = $volume->get_SIP_filename();
#        my $path_name = "$path/$file";
#        
#        return unlink $path_name;
#    }
#    
#    return 1;
#}

# unlink unpacked object
sub clean_unpacked_object{
    my $self = shift;
    my $dir = $self->{volume}->get_staging_directory();
    
    return remove_tree $dir;
}

# unlink zip
sub clean_zip{
    my $self = shift;
    my $dir = get_config('staging'=>'memory');
    my $zip_file = $self->{volume}->get_zip();
    my $zip_path = "$dir/$zip_file";
    
    return unlink $zip_path;
}

# unlink mets file
sub clean_mets{
    my $self = shift;
    my $mets = $self->{volume}->get_mets_path();
    
    return unlink $mets;
}


1;

__END__;
