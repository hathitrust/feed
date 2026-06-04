package HTFeed::Storage::ObjectStore;

use strict;
use HTFeed::Storage;
use base qw(HTFeed::Storage);

use Carp;
use File::Pairtree qw(id2ppath s2ppchars);
use HTFeed::Storage::S3;
use HTFeed::StorageAudit::ObjectStore;
use Log::Log4perl qw(get_logger);
use MIME::Base64 qw(decode_base64);
use POSIX qw(strftime);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{s3} ||= HTFeed::Storage::S3->new(
        bucket => $self->{config}{bucket},
        awscli => $self->{config}{awscli}
    );
    $self->{checksums} = {};

    $self->{tmp_key} = ".tmp" . sprintf("%08d",rand(1000000));

    return $self;
}

# Class method
sub zip_audit_class {
    my $class = shift;

    return 'HTFeed::StorageAudit::ObjectStore';
}

sub delete_objects {
    my $self = shift;

    my $mets = $self->mets_key;
    my $zip  = $self->zip_key;
    get_logger->trace("deleting $mets and $zip");
    eval {
        $self->{s3}->rm('/' . $mets);
        $self->{s3}->rm('/' . $zip);
    };
    if ($@) {
        $self->set_error(
            'OperationFailed',
            detail => "delete_objects failed: $@"
        );
        return;
    }
    return 1;
}

sub object_path {
    my $self = shift;

    $self->{timestamp} ||= strftime("%Y%m%d%H%M%S", gmtime);

    return join(
        ".",
        $self->{namespace},
        s2ppchars($self->{objid}),
        $self->{timestamp}
    );
}

sub cleanup {
  my $self = shift;

  my @keys = ($self->mets_key, $self->zip_key);

  foreach my $key (@keys) {
    my $old_key = $key . $self->{tmp_key} . ".old";

    if($self->{s3}->s3_has($old_key)) {
      $self->{s3}->rm($old_key);
    }
  }
}

sub clean_staging {
    # No staging path, so nothing to clean
}

sub stage_path {
    die("Not implemented for ObjectStore");
}

sub stage {
    my $self = shift;

    return $self->cp_to($self->{mets_source}, $self->mets_key . $self->{tmp_key}) &&
           $self->cp_to($self->{zip_source},  $self->zip_key . $self->{tmp_key});
}

sub prevalidate {
  # TODO copy postvalidate but use the tmp key
    return 1;
}

sub make_object_path {
    return 1;
}

sub zip_key {
    my $self = shift;

    return $self->object_path . $self->zip_suffix;
}

sub mets_key {
    my $self = shift;

    return $self->object_path . ".mets.xml";
}

sub zip_size {
    my $self = shift;
    return $self->{filesize}{$self->zip_key},
}

sub mets_size {
    my $self = shift;
    return $self->{filesize}{$self->mets_key},
}

sub zip_filename {
    my $self = shift;

    return $self->zip_key();
}

sub mets_filename {
    my $self = shift;

    return $self->mets_key();
}

sub postvalidate {
    my $self = shift;

    get_logger->trace("  starting postvalidate");
    foreach my $key ($self->zip_key, $self->mets_key) {
        my $s3path = "s3://$self->{s3}{bucket}/$key";
        my $result;

        eval {
            $result = $self->{s3}->s3api(
                'head-object',
                '--key' => $key
            )
        };

        if ($@ and $@ =~ /Not Found/) {
            $self->set_error(
                'MissingFile',
                file   => $s3path,
                detail => $@
            );

            return;
        }

        unless (exists $result->{Metadata}{'content-md5'}) {
            $self->set_error(
                'MissingField',
                field  => 'Content-MD5',
                file   => $s3path,
                detail => 'No md5 checksum recorded in object metadata'
            );

            return;
        }

        # FIXME $self->{checksums}{$key} can be missing?
        unless ($result->{Metadata}{'content-md5'} eq $self->{checksums}{$key}) {
            $self->set_error(
                'BadValue',
                field    => 'Content-MD5',
                file     => $s3path,
                actual   => $result->{Metadata}{'content-md5'},
                expected => $self->{checksums}{$key},
                detail   => 'Content-MD5 metadata value in S3 does not match expected value'
            );

            return;
        }
    }

    get_logger->trace("  finished postvalidate");

    # does it have the checksum metadata?
    return 1;
}

sub move {
    my $self = shift;

    my @keys = ($self->mets_key, $self->zip_key);

    foreach my $key (@keys) {
      if($self->{s3}->s3_has($key)) {
        $self->{s3}->rename($key, $key . $self->{tmp_key} . ".old") or return 0;
      }
    }

    foreach my $key (@keys) {
      my $tmp_key = $key . $self->{tmp_key};
      # move the new one into place
      $self->{s3}->rename($tmp_key, $key ) or return 0;
      $self->{checksums}{$key} = $self->{checksums}{$tmp_key};
      $self->{filesize}{$key}  = $self->{filesize}{$tmp_key};
    }

    return 1;

}

# Another possibility here:
#
# Use object versioning (which versitygw supports)
#
# When "move"ing, just upload a new version
#
# If we rollback, delete the version we uploaded, assuming this will make the
# previous version the current version.
#
# When we clean/commit, delete the previous version instead.

sub rollback {
  my $self = shift;

  my @keys = ($self->mets_key, $self->zip_key);

  foreach my $key (@keys) {
    if($self->{s3}->s3_has($key. $self->{tmp_key})) {
      $self->{s3}->rm($key . $self->{tmp_key});
    }
  }

  foreach my $key (@keys) {
    my $old_key = $key . $self->{tmp_key} . ".old";

    if($self->{s3}->s3_has($old_key)) {
      $self->{s3}->rename($old_key, $key);
    }
  }
}

sub cp_to {
    my $self   = shift;
    my $source = shift;
    my $key    = shift;

    my $md5_base64 = $self->md5_base64($source);

    $self->{checksums}{$key} = $md5_base64;
    $self->{filesize}{$key}  = -s $source;

    $self->{s3}->cp_to(
        $source,
        $key,
        "--metadata" => "content-md5=" . $md5_base64
    );
}

sub md5_base64 {
    my $self = shift;
    my $file = shift;

    open(my $fh, "<", $file) or croak("Can't open $file: $!");
    # From perldoc Digest::MD5:
    #
    # The base64 encoded string returned is not padded to be a multiple of 4
    # bytes long. If you want interoperability with other base64 encoded md5
    # digests you might want to append the string "==" to the result.

    return Digest::MD5->new->addfile($fh)->b64digest . '==';
}

sub record_audit {
    my $self = shift;

    $self->record_backup;
}

sub saved_md5sum {
    my $self = shift;

    my $b64_checksum = $self->{checksums}{$self->zip_key};
    my $hex_checksum = unpack("H*", decode_base64($b64_checksum));
}

sub record_backup {
    my $self = shift;

    get_logger->trace("  starting record_backup");
    my $dbh = HTFeed::DBTools::get_dbh();

    my $stmt = join(
        " ",
        "INSERT INTO feed_backups",
        "(namespace, id, path, version, storage_name,zip_size,",
        "mets_size, saved_md5sum, lastchecked, lastmd5check, md5check_ok)",
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1)"
    );

    my $sth  = $dbh->prepare($stmt);
    my $rval = $sth->execute(
        $self->{namespace},
        $self->{objid},
        $self->audit_path,
        $self->{timestamp},
        $self->{name},
        $self->zip_size,
        $self->mets_size,
        $self->saved_md5sum
    );

    get_logger->trace("  finished record_backup");

    return $rval;
}

sub audit_path {
    my $self = shift;

    return "s3://$self->{s3}{bucket}/" . $self->object_path;
}

sub request_glacier_object {
    my $self = shift;

    my $req_json = '{"Days":10,"GlacierJobParameters":{"Tier":"Bulk"}}';

    foreach my $file ($self->zip_filename, $self->mets_filename) {
      get_logger->trace("request_glacier_object: requesting $file");
      $self->{s3}->restore_object($file, '--restore-request', $req_json) or return 0;
    }

    return 1;
}

# Returns 1 if both the zip and METS could be restored on the local filesystem.
sub restore_glacier_object {
    my $self = shift;
    my $dest = shift;

    my $zip = $self->zip_filename;
    my $mets = $self->mets_filename;

    return 0 unless $self->check_glacier_object;

    foreach my $file ($self->zip_filename, $self->mets_filename) {
      get_logger->trace("restore_glacier_object: restoring $file to $dest");
      $self->{s3}->get_object(
        $self->{s3}->{'bucket'},
        $file,
        $dest . '/' . $file
      ) or return 0;
    }

    return 1;
}

# Returns 1 only if both zip and METS are ready for download.
sub check_glacier_object {
    my $self = shift;

    foreach my $file ($self->zip_filename, $self->mets_filename) {
      my $result = $self->{s3}->head_object($file);
      return 0 unless ($result->{Restore} && $result->{Restore} =~ m/ongoing-request\s*=\s*"false"/);
    }

    return 1;
}

1;
