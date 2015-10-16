package HTFeed::Volume;

use warnings;
use strict;
use Carp;
use Log::Log4perl qw(get_logger);
use HTFeed::XMLNamespaces qw(register_namespaces);
use HTFeed::XPathValidator qw(:closures);
use HTFeed::Namespace;
use HTFeed::FileGroup;
use XML::LibXML;
use HTFeed::Config qw(get_config);
use HTFeed::DBTools;
use Time::gmtime;
use File::Pairtree qw(id2ppath s2ppchars);
use Data::UUID;
use File::Path qw(remove_tree mkpath);
use File::Basename qw(dirname);
use File::Copy qw(move);

# singleton stage_map override
my $stage_map = undef;

# The namespace UUID for HathiTrust
use constant HT_UUID => '09A5DAD6-3484-11E0-9D45-077BD5215A96';

sub new {
  my $package = shift;

  my $self = {
    objid     => undef,
    namespace => undef,
    packagetype => undef,
    uuidgen => new Data::UUID,
    @_,

    #		files			=> [],
    #		dir			=> undef,
    #		mets_name		=> undef,
    #		mets_xml		=> undef,
  };

  $self->{nspkg} = HTFeed::Namespace->new($self->{namespace},$self->{packagetype});

  if($self->{nspkg}->validate_barcode($self->{objid})) {
    my $class = $self->{nspkg}->get('volume_module');

    bless( $self, $class );
    return $self;
  } else {
    get_logger()->error("BadValue",namespace=>$self->{namespace},objid=>$self->{objid},field=>'barcode',detail=>'Invalid barcode');
    croak("VOLUME_ERROR");
  }
}

# invalidate cached information between jobs
sub reset {
  my $self = shift;
  my @fields = qw(checksums content_files source_mets_file source_mets_xpc
  repsitory_mets_xpc jhove_files utf8_files repository_symlink page_data
  filegroups ingest_date); 

  map { delete $self->{$_} } @fields;
}

sub get_identifier {
  my $self = shift;
  return $self->get_namespace() . q{.} . $self->get_objid();

}

sub get_namespace {
  my $self = shift;
  return $self->{namespace};
}

sub get_objid {
  my $self = shift;
  return $self->{objid};
}

sub get_packagetype {
  my $self = shift;
  return $self->{packagetype};
}

sub get_pt_objid {
  my $self = shift;
  return s2ppchars($self->{objid});
}

sub get_file_groups {
  my $self = shift;

  if(not defined $self->{filegroups}) {
    my $filegroups = {}; 

    my $nspkg_filegroups = $self->{nspkg}->get('filegroups');
    while( my ($key,$val) = each (%{ $nspkg_filegroups })) {
      my $files = [];
      my $re = $val->{file_pattern} or die("Missing pattern for filegroup $key");
      foreach my $file ( @{ $self->get_all_directory_files() }) {
        push(@$files,$file) if $file =~ $re;
      }
      $filegroups->{$key} = new HTFeed::FileGroup($files,%$val);
    }
    $self->{filegroups} = $filegroups;
  }

  return $self->{filegroups};
}

sub get_all_directory_files {
  my $self = shift;

#    if(not defined $self->{directory_files}) {
  $self->{directory_files} = [];
  my $stagedir = $self->get_staging_directory();
  opendir(my $dh,$stagedir) or croak("Can't opendir $stagedir: $!");
  foreach my $file (readdir $dh) {
    # ignore ., .., Mac .DS_Store files
    push(@{ $self->{directory_files} },$file) unless ($file =~ /^\.+$/ or $file eq '.DS_Store');
  }
  closedir($dh) or croak("Can't closedir $stagedir: $!");
  @{ $self->{directory_files} } = sort( @{ $self->{directory_files} } );
#    }

  return $self->{directory_files};
}

sub get_sources {
  my $self = shift;
  my $dbh = HTFeed::DBTools::get_dbh();
  my $sth = $dbh->prepare("SELECT content_provider_cluster, responsible_entity, n.collection, s.digitization_source, d.access_profile from feed_zephir_items n 
                            JOIN ht_collections c ON n.collection = c.collection 
                            LEFT JOIN ht_collection_digitizers d ON n.collection = d.collection 
                              AND n.digitization_source = d.digitization_source 
                            JOIN ht_rights.sources s on n.digitization_source = s.name 
                            WHERE n.namespace = ? and n.id = ?");
  $sth->execute($self->get_namespace(),$self->get_objid());
  if(my ($content_providers,$responsible_entity,$collection,$digitization_agents,$access_profile) = $sth->fetchrow_array()) {
    if(!$access_profile) {
      $self->set_error("BadValue",field=>"digitization_agent",actual=>$digitization_agents,detail=>"Unexpected digitization agent(s) $digitization_agents for collection $collection");
    }
    return ($content_providers,$responsible_entity,$digitization_agents);
  } else {
#    my $mets_xpc = $self->get_repository_mets_xpc();
#    my @content_providers;
#    my @responsible_entities;
#    my @digitization_agents;
#
#    if($mets_xpc) {
#      foreach my $contentProvider ($mets_xpc->findnodes('//ht:contentProvider')) {
#        my $contentProviderCode = $contentProvider->textContent();
#        $contentProviderCode .= '*' if $contentProvider->getAttribute('display') eq 'yes';
#        push(@content_providers,[$contentProvider->getAttribute('sequence'),$contentProviderCode]);
#      }
#      foreach my $responsibleEntity ($mets_xpc->findnodes('//ht:responsibleEntity')) {
#        my $responsibleEntityCode = $responsibleEntity->textContent();
#        push(@responsible_entities,[$responsibleEntity->getAttribute('sequence'),$responsibleEntityCode]);
#      }
#      foreach my $digitization_agent ($mets_xpc->findnodes('//ht:digitizationAgent')) {
#        my $digitization_agent_code = $digitization_agent->textContent();
#        $digitization_agent_code .= '*' if $digitization_agent->getAttribute('display') eq 'yes';
#        push(@digitization_agents,$digitization_agent_code);
#      }
#    }

    # not found in DB or existing METS
#    if(!@content_providers or !@responsible_entities) {
      $self->set_error("MissingField",field=>"sources",detail=>"Can't get content provider / responsible entity / digitization agent from feed_zephir_items");
#    } else {
#      return (join(';',map { $_->[1] } sort { $a->[0] <=> $b->[0] } @content_providers),
#        join(';',map { $_->[1] } sort { $a->[0] <=> $b->[0] } @responsible_entities),
#        join(';',@digitization_agents))
#    }
  }
}

sub get_access_profile {
  my $self = shift;
  my $dbh = HTFeed::DBTools::get_dbh();
  my $sth = $dbh->prepare("SELECT collection, digitization_source FROM feed_zephir_items WHERE namespace = ? and id = ?");

  $sth->execute($self->get_namespace(),$self->get_objid());
  my ($collection,$digitization_source) = $sth->fetchrow_array();

  # not in feed_zephir_items, try to get from rights_current
  if(not defined $collection or not defined $digitization_source) {
#    $sth = $dbh->prepare("SELECT access_profile FROM rights_current WHERE namespace = ? and id = ?");
#    $sth->execute($self->get_namespace(),$self->get_objid());
#    if(my ($access_profile) = $sth->fetchrow_array()) {
#      return $access_profile;
#    } else {
      $self->set_error("MissingField",field=>"access profile",detail=>"Item not in feed_zephir_items; can't determine access profile");
#    }
  }

  # try to map collection, digitization source to access profile
  $sth = $dbh->prepare("SELECT access_profile FROM feed_collection_digitizers WHERE collection = ? and digitization_source = ?");
  $sth->execute($collection,$digitization_source);
  if(my ($access_profile) = $sth->fetchrow_array()) {
    return $access_profile;
  } else {
    $self->set_error("BadValue",field=>"collection code",actual=>"$collection / $digitization_source",detail=>"Unknown collection code or unexpected digitization source");
  }

}


sub get_staging_directory {
  my $self = shift;
  my $pt_objid = $self->get_pt_objid();
  return get_config('staging'=>'ingest') . q(/) . $pt_objid;
}

sub get_zip_directory {
  my $self = shift;
  my $pt_objid = $self->get_pt_objid();
  return get_config('staging'=>'zipfile') . q(/) . $pt_objid;
}

sub get_zip_path {
  my $self = shift;
  return $self->get_zip_directory() . q(/) . $self->get_zip_filename();
}

sub get_download_directory {
  return get_config('staging'=>'download');
}

sub get_sip_directory {
    return get_config('staging'=>'fetch');
}

sub get_sip_success_directory {
    return get_config('staging'=>'ingested');
}

sub get_sip_failure_directory {
    return get_config('staging'=>'punted');
}

sub get_all_content_files {
  my $self = shift;

  if(not defined $self->{content_files}) {
    foreach my $filegroup (values(%{ $self->get_file_groups()})) {
      push(@{ $self->{content_files} },@{ $filegroup->get_filenames() }) if $filegroup->{content};
    }
  }

  return $self->{content_files};
}

# by default get checksums from source METS
sub get_checksums {
  my $self = shift;
  return $self->get_checksum_mets();
}

# get checksums from checksum.md5 (call in subclasses)
sub get_checksum_md5 {
  my $self = shift;
  my $path = shift;
  $path = $self->get_staging_directory() if not defined $path;

  if (not defined $self->{checksums_file} ){
    my $checksum_file = $self->get_nspkg()->get('checksum_file');
    my $checksum_path = "$path/$checksum_file";

    my $checksum;
    my $filename;

    my $checksums = {};

    open(FILE, $checksum_path) or die $!;		
    foreach my $line(<FILE>) {
      $line =~ s/\r\n$/\n/;
      chomp($line);
      # ignore malformed lines
      next unless $line =~ /^([a-fA-F0-9]{32})(\s+\*?)(\S.*)/;
      $checksum = lc($1);
      $filename = lc($3);
      $filename =~ s/.*\///; # strip pathnames, since we junked them from the zip file
      $checksums->{$filename} = $checksum;
    }	
    $self->{checksums_file} = $checksums;
    close(FILE);
  }
  return $self->{checksums_file};

}


sub get_checksum_mets {
  my $self = shift;

  if ( not defined $self->{checksums_mets} ) {

    my $checksums = {};
    # try to extract from source METS
    my $xpc = $self->_checksum_mets_xpc();
    foreach my $node ( $xpc->findnodes('//mets:file') ) {
      my $checksum = $xpc->findvalue( './@CHECKSUM', $node );
      my $filename =
      $xpc->findvalue( './mets:FLocat/@xlink:href', $node );
      $checksums->{$filename} = $checksum;
    }

    $self->{checksums_mets} = $checksums;
  }

  return $self->{checksums_mets};
}

# override in Volume subclass to fetch checksums from a different METS file
sub _checksum_mets_xpc {
  my $self = shift;
  return $self->get_source_mets_xpc();
}

#TODO: support more general creation, substitution of templates in METS file
sub get_source_mets_file {
  my $self = shift;
  if(not defined $self->{source_mets_file}) {
    my $src_mets_re = $self->{nspkg}->get('source_mets_file');

    foreach my $file ( @{ $self->get_all_directory_files() }) {
      if($file =~ $src_mets_re) {
        if(not defined $self->{source_mets_file}) {
          $self->{source_mets_file} = $file;
        } else {
          croak("Two or more files match source METS RE $src_mets_re: $self->{source_mets_file} and $file");
        }
      }
    }
  }

  return $self->{source_mets_file};
}

sub get_source_mets_xpc {
  my $self = shift;

  if(not defined $self->{source_mets_xpc}) {
    my $mets = $self->get_source_mets_file();
    my $path = $self->get_staging_directory();

    die("Missing METS file") unless defined $mets and defined $path;
    $self->{source_mets_xpc} = $self->_parse_xpc("$path/$mets");

  }
  return $self->{source_mets_xpc};

}

# merges per-volume validation overrides (from note from mom) with
# package type validation overrides
sub get_validation_overrides {
  my $self = shift;
  my $module = shift;

  my $overrides = $self->get_nspkg()->get_validation_overrides($module);

    # if there is a 'note from mom' for TIFF resolution, just check that
    # they are present and equal
    if($module eq 'HTFeed::ModuleValidator::TIFF_hul' and
        !$self->should_check_validator('tiff_resolution')) {
        $overrides->{resolution} = HTFeed::ModuleValidator::TIFF_hul::v_resolution_exists();
    }

  return $overrides;
}

# return true if we should do particular validation checks - false if we're
# using the 'note from mom' for that check or disabling validation for this volume
sub should_check_validator {
  my $self = shift;

  my $validator = shift;
  my $src_mets = $self->get_source_mets_file();
  my $xpc;

  my @skip_validation = @{$self->get_nspkg()->get('skip_validation')};
  # get exceptions from 'note from mom' PREMIS event
  if(not defined $self->{note_from_mom} and 
    defined $src_mets) {
    $xpc = $self->get_source_mets_xpc();
  }

  # get from database if there is no source METS file
  if (not defined $self->{note_from_mom} and
    not defined $src_mets) {
    my ($eventid, $date, $outcome_node, $custom_node) = $self->get_event_info('note_from_mom');
    if($custom_node)  {
      $xpc = XML::LibXML::XPathContext->new($custom_node);
      register_namespaces($xpc);
    }
  }

  if(defined $xpc) {
    $self->{note_from_mom} = [];
    foreach my $exception_node ($xpc->findnodes('//premis:event[premis:eventType="manual inspection"]//htpremis:exceptionsAllowed/@category')) {
      push(@{$self->{note_from_mom}},$exception_node->getValue());
    }
  }

  if(defined $self->{note_from_mom}) {
    push(@skip_validation,@{$self->{note_from_mom}});
  }

  if(grep {$_ eq $validator} @skip_validation) {
    return 0;
  } else {
    return 1;
  }
}

# Returns an XML::LibXML::XPathContext with namespaces set up
# and the context node positioned at the document root of the given XML file.
sub _parse_xpc {
  my $self = shift;
  my $file = shift;
  my $xpc;
  eval {
    die "Missing file $file" unless -e "$file";
    my $parser = XML::LibXML->new();
    my $doc    = $parser->parse_file("$file");
    $xpc = XML::LibXML::XPathContext->new($doc);
    register_namespaces($xpc);
  };

  if ($@) {
    if(ref($@ eq 'HASH')) {
      $self->set_error("BadFile",file => $file,detail=>$@->{message});
    } else {
      $self->set_error("BadFile",file => $file,detail=>$@);
    }
  } else {
    return $xpc;
  }
}

sub get_repository_mets_xpc {
  my $self = shift;

  if (not defined $self->{repository_mets_xpc}) {

    my $mets = $self->get_repository_mets_path();
    return unless defined $mets;

    $self->{repository_mets_xpc} = $self->_parse_xpc($mets);
  }

  return $self->{repository_mets_xpc};

}

sub get_nspkg{
  my $self = shift;
  return $self->{nspkg};
}

sub get_stages{
  my $self = shift;
  my $stage_map = $self->get_stage_map();
  my $stage_name = shift;
  $stage_name = 'ready' if not defined $stage_name;
  my $stages = [];
  my $stage_class;

  while ($stage_class = $stage_map->{$stage_name}){
    push ( @{ $stages }, $stage_class );
    $stage_name = eval "$stage_class->get_stage_info('success_state')";
  }

  return $stages;
}


sub get_jhove_files {
  my $self = shift;
  if(not defined $self->{jhove_files}) {
    foreach my $filegroup (values(%{ $self->get_file_groups()})) {
      push(@{ $self->{jhove_files} },@{ $filegroup->get_filenames() }) if $filegroup->{jhove};
    }
  }

  return $self->{jhove_files};
}

sub get_utf8_files {
  my $self = shift;
  if(not defined $self->{utf8_files}) {
    foreach my $filegroup (values(%{ $self->get_file_groups()})) {
      push(@{ $self->{utf8_files} },@{ $filegroup->get_filenames() }) if $filegroup->{utf8};
    }
  }

  return $self->{utf8_files};
}

sub get_marc_xml {
  my $self = shift;
  my $marcxml_doc;

  my $mets_xc = $self->get_source_mets_xpc();
  my $mdsec_nodes = $mets_xc->find(
    q(//mets:dmdSec/mets:mdWrap[@MDTYPE="MARC"]/mets:xmlData));

  if ( $mdsec_nodes->size() ) {
    get_logger()->warn("Multiple MARC mdsecs found") if ( $mdsec_nodes->size() > 1 );
    my $node = $mdsec_nodes->get_node(0)->firstChild();
    # ignore any whitespace, etc.
    while($node->nodeType() != XML_ELEMENT_NODE) {
      $node = $node->nextSibling();
    }
    if(defined $node) {
      # check & remediate MARC
      my $marc_xc = new XML::LibXML::XPathContext($node);
      register_namespaces($marc_xc);
      HTFeed::METS::_remediate_marc($self,$marc_xc);
      return $node;
    }
  } 

  # no metadata found, or metadata node didn't contain anything
  $self->set_error("BadField",field=>"marcxml",file => $self->get_source_mets_file(),detail=>"Could not find MARCXML in source METS");

}

sub get_repository_symlink {
  my $self = shift;


  if(not defined $self->{repository_symlink}) {
    my $link_dir = get_config("repository","link_dir");
    my $namespace = $self->get_namespace();

    my $objid = $self->get_objid();

    my $pairtree_path = id2ppath($objid);

    my $pt_objid = $self->get_pt_objid();

    my $symlink = "$link_dir/$namespace/$pairtree_path/$pt_objid";
    $self->{repository_symlink} = $symlink;
  }

  return $self->{repository_symlink};
}

sub get_repository_mets_path {
  my $self = shift;

  my $repos_symlink = $self->get_repository_symlink();

  return unless (-l $repos_symlink or -d $repos_symlink);

  my $mets_in_repository_file = sprintf("%s/%s.mets.xml",
    $repos_symlink,
    $self->get_pt_objid());

  return unless (-f $mets_in_repository_file);
  return $mets_in_repository_file;
}

sub get_repository_zip_path {
  my $self = shift;

  my $repos_symlink = $self->get_repository_symlink();

  return unless (-l $repos_symlink or -d $repos_symlink);

  my $zip_in_repository_file = sprintf("%s/%s.zip",
    $repos_symlink,
    $self->get_pt_objid());

  return unless (-f $zip_in_repository_file);
  return $zip_in_repository_file;
}

sub get_file_count {

  my $self = shift;
  return scalar(@{$self->get_all_content_files()});
}

sub get_page_count {
  my $self = shift;
  my $image_group = $self->get_file_groups()->{image};
  croak("Page count requested for object with no image filegroup") unless defined $image_group;
  return scalar(@{ $image_group->get_filenames() });
}

sub get_required_file_groups_by_page {
  my $self = shift;

  return $self->get_file_groups_by_page( sub { return $_[0]->get_required(); } )

}

sub get_structmap_file_groups_by_page {
  my $self = shift;

  return $self->get_file_groups_by_page( sub { return $_[0]->in_structmap(); } )
}

sub get_file_groups_by_page {
  my $self = shift;
  my $condition = shift;
  my $filegroups      = $self->get_file_groups();
  my $files           = {};

  # First determine what files belong to each sequence number
  while ( my ( $filegroup_name, $filegroup ) =
    each( %{ $filegroups } ) )
  {
    # ignore this filegroup if there is a condition given and the filegroup
    # doesn't meet the condition (see other get_*_file_groups_by_pagE)
    next if defined($condition) and not &$condition($filegroup);
    foreach my $file ( @{$filegroup->get_filenames()} ) {
      if ( $file =~ /(\d+)\.(\w+)$/ ) {
        my $sequence_number = $1;
        if(not defined $files->{$sequence_number}{$filegroup_name}) {
          $files->{$sequence_number}{$filegroup_name} = [$file];
        } else {
          push(@{ $files->{$sequence_number}{$filegroup_name} }, $file);
        }
      }
      else {
        croak("Can't get sequence number for $file");
      }
    }
  }

  return $files;
}

sub record_premis_event {
  my $self = shift;
  my $eventcode = shift;
  my $eventconfig = $self->get_nspkg()->get_event_configuration($eventcode);
  my %params = @_;

  my $dbh = HTFeed::DBTools::get_dbh();

  if(defined $params{custom_event}) {
    my $custom_event = $params{custom_event};
    my $set_premis_sth = $dbh->prepare("REPLACE INTO feed_premis_events (namespace, id, eventtype_id, custom_xml) VALUES (?, ?, ?, ?)");
    $set_premis_sth->execute($self->get_namespace(),$self->get_objid(),$eventcode,$custom_event->toString());
  } else {
    my $eventtype = $eventconfig->{'type'};
    croak("Event code / type not found") unless $eventtype;

    my $date = ($params{date} or $self->_get_current_date());

    my $outcome_xml = $params{outcome}->to_node()->toString() if defined $params{outcome};

    my $uuid = $self->make_premis_uuid($eventtype,$date); 

    $dbh->do("SET time_zone = '+00:00'") if($dbh->{Driver}->{Name} eq 'mysql');
    my $set_premis_sth = $dbh->prepare("REPLACE INTO feed_premis_events (namespace, id, eventid, eventtype_id, outcome, date) VALUES (?, ?, ?, ?, ?, ?)");

    $set_premis_sth->execute($self->get_namespace(),$self->get_objid(),$uuid,$eventcode,$outcome_xml,$date);
  }

}

sub make_premis_uuid {
  my $self = shift;
  my $eventtype = shift;
  my $date = shift;
  $date =  $self->_get_current_date() if not defined $date;
  my $tohash = join("-",$self->get_namespace(),$self->get_objid(),$eventtype,$date);
  my $uuid = $self->{uuidgen}->create_from_name_str(HT_UUID,$tohash);
  return $uuid;
}

sub get_event_info {
  my $self = shift;
  my $eventtype = shift;

  my $dbh = HTFeed::DBTools::get_dbh();

  $dbh->do("SET time_zone = '+00:00'") if $dbh->{Driver}->{Name} eq 'mysql';
  my $event_sql = "SELECT eventid,date,outcome,custom_xml FROM feed_premis_events where namespace = ? and id = ? and eventtype_id = ?";

  my $event_sth = $dbh->prepare($event_sql);
  my @params = ($self->get_namespace(),$self->get_objid(),$eventtype);

  my @events = ();

  $event_sth->execute(@params);
  # Should only be one event of each event type - enforced by primary key in DB
  if (my ($eventid, $date, $outcome, $custom) = $event_sth->fetchrow_array()) {
    # replace space separating date from time with 'T'; add Z
    $date =~ s/ /T/g;
    $date .= 'Z' unless $date =~ /([+-]\d{2}:\d{2})|Z$/;
    my $outcome_node = undef;
    if($outcome) {
      $outcome_node = XML::LibXML->new()->parse_string($outcome);
      $outcome_node = $outcome_node->documentElement();
    }
    my $custom_node = undef;
    if($custom) {
      $custom_node = XML::LibXML->new()->parse_string($custom);
      $custom_node = $custom_node->documentElement();
    }
    return ($eventid, $date, $outcome_node, $custom_node);
  } else {
    return;
  }
}

sub _get_current_date {

  my $self = shift;
  my $ss1970 = shift;

  my $gmtime_obj = defined($ss1970) ? gmtime($ss1970) : gmtime();

  my $ts = sprintf("%d-%02d-%02dT%02d:%02d:%02dZ",
    (1900 + $gmtime_obj->year()),
    (1 + $gmtime_obj->mon()),
    $gmtime_obj->mday(),
    $gmtime_obj->hour(),
    $gmtime_obj->min(),
    $gmtime_obj->sec());

  return $ts;
}

sub get_zip_filename {
  my $self = shift;
  my $pt_objid = $self->get_pt_objid();

  return "$pt_objid.zip";
}

# get page data from source METS by default
sub get_page_data {
  my $self = shift;
  my $file = shift;

  (my $seqnum) = ($file =~ /(\d+)\./);
  croak("Can't extract sequence number from file $file") unless $seqnum;

  if(not defined $self->{'page_data'} ) {
    my $pagedata = {};

    my $xc = $self->get_source_mets_xpc();
    foreach my $page ($xc->findnodes('//METS:structMap/METS:div/METS:div')) {
      my $order = sprintf("%08d",$page->getAttribute('ORDER'));
      my $detected_pagenum = $page->getAttribute('ORDERLABEL');
      my $tag = $page->getAttribute('LABEL');
      $pagedata->{$order} = {
        orderlabel => $detected_pagenum,
        label => $tag
      }
    }
    $self->{page_data} = $pagedata;
  }

  return $self->{page_data}{$seqnum};
}

sub get_mets_path {
  my $self = shift;

  my $staging_path = get_config('staging'=>'ingest');
  my $pt_objid = $self->get_pt_objid();
  my $mets_path = "$staging_path/$pt_objid.mets.xml";

  return $mets_path;
}

sub get_SIP_filename {
  my $self = shift;
  my $objid = $self->{objid};
  my $pattern = $self->{nspkg}->get('SIP_filename_pattern');
  return sprintf($pattern,$objid);
}

=item get_preingest_directory

Returns the directory where the raw submitted object is staged.  By default, if
use_preingest is defined and true in the package type configuration, returns
get_config('staging'=>'preingest')/$objid, and undef if use_preingest is false
or not defined. Note that by default the name of the preingest directory
is NOT pairtree-encoded.

=cut

sub get_preingest_directory {
  my $self = shift;

  if($self->{nspkg}->get('use_preingest')) {
    my $pt_objid = $self->get_pt_objid();
    return sprintf("%s/%s", get_config('staging'=>'preingest'), $pt_objid);
  } else { return; }
}

sub get_download_location {
    my $self = shift;
    my $staging_dir = $self->get_download_directory();
    return "$staging_dir/" . $self->get_SIP_filename();
}

sub get_sip_location {
  my $self = shift;
  my $staging_dir = $self->get_sip_directory();
  my $namespace = $self->get_namespace();
  return "$staging_dir/$namespace/" . $self->get_SIP_filename();
}

sub get_success_sip_location {
  my $self = shift;
  my $staging_dir = $self->get_sip_success_directory();
  my $namespace = $self->get_namespace();
  return "$staging_dir/$namespace/" . $self->get_SIP_filename();
}

sub get_failure_sip_location {
  my $self = shift;
  my $staging_dir = $self->get_sip_failure_directory();
  my $namespace = $self->get_namespace();
  return "$staging_dir/$namespace/" . $self->get_SIP_filename();
}

sub clear_premis_events {
  my $self = shift;

  my $ns = $self->get_namespace();
  my $objid = $self->get_objid();
  my $sth = HTFeed::DBTools::get_dbh()->prepare("DELETE FROM feed_premis_events WHERE namespace = ? and id = ?");
  $sth->execute($ns,$objid);

}

sub remove_premis_event {
  my $self = shift;
  my $eventcode = shift;

  my $ns = $self->get_namespace();
  my $objid = $self->get_objid();
  my $sth = HTFeed::DBTools::get_dbh()->prepare("DELETE FROM feed_premis_events WHERE namespace = ? and id = ? and eventtype_id = ?");
  $sth->execute($ns,$objid,$eventcode);
}


# remove staging directory
sub _clean_vol_path {
  my $self = shift;
  my $stagetype = shift;

  foreach my $ondisk (0,1) {
    my $dir = eval "\$self->get_${stagetype}_directory($ondisk)";
    if(defined $dir and -e $dir) {
      get_logger()->debug("Removing " . $dir);
      remove_tree $dir;
    }
  }
}

# unlink unpacked object
sub clean_unpacked_object {
  my $self = shift;
  return $self->_clean_vol_path('staging');
}

# unlink zip
sub clean_zip {
  my $self     = shift;
  return $self->_clean_vol_path('zip');
}

# unlink mets file
sub clean_mets {
  my $self = shift;
  return unlink $self->get_mets_path();
}

# unlink preingest directory tree
sub clean_preingest {
  my $self = shift;
  return $self->_clean_vol_path('preingest');
}

sub clean_sip_success {
  my $self = shift;
  $self->move_sip($self->get_success_sip_location());
}

sub clean_sip_failure {
  my $self = shift;
  $self->move_sip($self->get_failure_sip_location());
}

sub move_sip {
  my $self = shift;
  my $source = $self->get_sip_location();
  if( not -e $source) {
    $source = $self->get_failure_sip_location(); # for retries
  }


  my $target = shift;


  if( -e $source and $source ne $target) {
    if( not -d dirname($target) ) {
      mkpath(dirname($target)) or $self->set_error("OperationFailed",operation => "mkpath",file => $target,detail=>$!);
    }

    move($source,$target) or $self->set_error("OperationFailed",operation => "move",file => $source,detail=>$!);
  }
}

sub clean_download {
  die("not implemented for HTFeed::Volume");
}

sub ingested{
  my $self = shift;
  my $link = $self->get_repository_symlink();

  return 1 if (-e $link);
  return;
}

sub set_error {
  my $self  = shift;
  my $error = shift;

  # log error w/ l4p
  my $logger = get_logger( ref($self) );
  $logger->error(
    $error,
    namespace => $self->get_namespace(),
    objid     => $self->get_objid(),
    @_
  );

  croak("VOLUME_ERROR");
}

# override nspkg stage map FOR ALL VOLUME OBJECTS
sub set_stage_map {
  my $new_stage_map = shift;

  croak 'new stage map must be a hash ref'
  unless (ref $new_stage_map eq 'HASH');
  $stage_map = $new_stage_map;

  _require_modules(values(%$new_stage_map));

  return;
}

sub clear_stage_map {
  $stage_map = undef;
  return;
}

# TODO: merge this with PackageType::require_modules and move to a common location
sub _require_modules {
  foreach my $module (@_) {
    my $modname = $module;
    next unless defined $modname and $modname ne '';
    $modname =~ s/::/\//g;
    require $modname . ".pm";
  }
}

sub get_stage_map {
  my $self = shift;
  my $stage_map = ($stage_map or $self->get_nspkg()->get('stage_map'));
  return $stage_map;
}

sub next_stage {
  my $self = shift;
  my $stage_map = $self->get_stage_map();
  my $stage_name = shift;
  $stage_name = 'ready' if not defined $stage_name;
  if(not defined $stage_map->{$stage_name}) {
    $self->set_error("UnexpectedError",detail => "Action for stage $stage_name not defined");
  }
  return $stage_map->{$stage_name};
}

sub apparent_digitizer {
  my $self = shift;
  # just use digitization agent from Zephir
  my (undef,undef,$digitization_agents) = $self->get_sources();
  my $capture_agent = undef;
  foreach my $agentid (split(';',$digitization_agents)) {
    if($agentid =~ /\*$/ or not defined $capture_agent) {
      $agentid =~ s/\*$//;
      $capture_agent = $agentid;
    }
  }
  return $capture_agent;
}

1;

__END__

=head1 NAME

HTFeed::Volume - Feed volume manager

=head1 SYNOPSIS

Parent class for volume maintenence.

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item new()

=item get_identifier()

Returns the full identifier (namespace.objid) for the volume

=item get_namespace()

Returns the namespace identifier for the volume

=item get_objid()

Returns the ID (without namespace) of the volume.

=item get_packagetype()

Returns the packagetype of the volume.

=item get_pt_objid()

Returns the pairtreeized ID of the volume

=item get_file_groups()

Returns a hash of HTFeed::FileGroup objects containing info about the logical groups
of files in the objects. Configure through the filegroups package type setting.

=item get_all_directory_files()

Returns a list of all files in the staging directory for the volume's AIP

=item get_staging_directory()

Returns the staging directory for the volume's AIP
returns path to staging directory on disk if $ondisk

=item get_zip_directory()

Returns the path to the directory where the zip archive for this
object will be constructed. If $ondisk is set, returns a path
on disk rather than in RAM.

=item get_zip_path()

Returns the full path (directory + filename) for the zip archive
for this object. 

=item get_download_directory()

Returns the directory the volume's SIP should be downloaded to

=item get_all_content_files()

Returns a list of all files that will be validated.

=item get_checksums()

Returns a hash of precomputed checksums for files in the package's AIP where
the keys are the filenames and the values are the MD5 checksums.

=item get_source_mets_file()

Returns the name of the source METS file

=item get_source_mets_xpc()

Returns an XML::LibXML::XPathContext with namespaces set up 
and the context node positioned at the document root of the source METS.

=item get_repository_mets_xpc()

Returns an XML::LibXML::XPathContext with namespaces set up 
and the context node positioned at the document root of the repository METS, if
the object is already in the repository. Returns false if the object is not
already in the repository.

=item get_nspkg

Returns the HTFeed::Namespace object that provides namespace & package type-
specific configuration information.

=item get_stages()

Returns array ref containing a list of stages this Volume needs for a full ingest process,
starting from the given start state, or 'ready' if none is specified.

$stages = get_stages($start_state);

=item get_jhove_files()

Get all files that will need to have their metadata validated with JHOVE

=item get_utf8_files()

Get all files that should be valid UTF-8

=item get_marc_xml()

Returns an XML::LibXML node with the MARCXML

=item get_repository_symlink()

Returns the path to the repository symlink for the object.
(or the directory if the repository does not use symlinks)

=item get_repository_mets_path()

Returns the full path where the METS file for this object 
would be, if this object was in the repository.

=item get_repository_zip_path()

Returns the full path where the zip file for this object 
would be, if this object was in the repository.

=item get_filecount()

Returns the total number of content files

=item get_page_count()

Returns the number of pages in the volume as determined by the number of
images.

=item get_files_by_page()

Returns a data structure listing what files belong to each file group in
physical page, e.g.:

{ '0001' => { txt => ['0001.txt'], 
          img => ['0001.jp2'] },
  '0002' => { txt => ['0002.txt'],
          img => ['0002.tif'] }, '0003' => { txt => ['0003.txt'],
          img => ['0003.jp2','0003.tif'] }
  };

=item record_premis_event()

Records a PREMIS event that happens to the volume. Optionally, a
PREMIS::Outcome object can be passed. If no date (in any format parseable by
MySQL) is given, the current date will be used. The date is assumed to be UTC.
If the PREMIS event has already been recorded in the database, the date and
outcome will be updated.

The eventtype_id refers to the event definitions in the application configuration file, not
the PREMIS eventType (which is configured in the event definition)

record_premis_event($eventtype_id, date => $date, outcome => $outcome);

=item make_premis_uuid()

Returns a UUID for a PREMIS event for this object of type $eventtype occurring
at time $date.  There is no required format for the date, but it should be
consistent to get stable UUIDs for events occurring at the same time.

make_premis_uuid($eventtype,$date);

=item get_event_info()

Returns the date and outcome for the given event type for this volume.

$outcome = get_event_info($eventtype);

=item _get_current_date()

Returns the current date and time in a format parseable by MySQL

=item get_zip_filename()

Returns the basename of the zip file to construct for this
object.

=item get_page_data()

Returns a reference to a hash:

    { orderlabel => page number
      label => page tags }

for the page containing the given file.

If there is no detected page number or page tags for the given page,
the corresponding entry in the hash will not exist.

$ref = get_page_data($file);

=item get_mets_path()

Returns the path to the METS file to construct for this object

=item get_SIP_filename()

Returns the SIP's filename

=item get_preingest_directory()

Returns the directory where the raw submitted object is staged. 
Returns undef by default; package type subclasses must define.

should use get_config('staging'=>'preingest') as a base dir

=item get_download_location()

Returns the file or path (if the SIP consists of multiple files) to download
the volume to. This file or path will be removed when the volume is successfully
ingested.

=item clear_premis_events()

Deletes the PREMIS events for this volume. Typically used when the volume has been collated
and there is no longer a need to retain the PREMIS events in the database.

=item ingested()

Returns true if item is already in the repository

=item set_error()

For compatibility with HTFeed::Stage - logs an error 
with the namespace and object ID set, and croaks no 
matter what (as that is the expectation with Volume)

=item next_stage()

Returns string containing the name of the next stage this Volume needs for ingest

$next_stage = next_stage($start_state);

=item clean_zip()

=item get_file_groups_by_page()

=item clean_mets()

=item set_stage_map()

=item get_required_file_groups_by_page()

=item get_file_count()

=item clean_preingest()

=item clean_download()

=item clean_unpacked_object()

=item get_structmap_file_groups_by_page()

=back

INSERT_UNIVERSITY_OF_MICHIGAN_COPYRIGHT_INFO_HERE

=cut
