use HTFeed::Config qw(get_config);

local our ($s3, $bucket);

before all => sub {
  $bucket = "bucket" . sprintf("%08d",rand(1000000));
  $s3 = HTFeed::Storage::S3->new(
    bucket => $bucket,
    awscli => get_config('test_awscli')
  );
  $ENV{AWS_MAX_ATTEMPTS} = 1;

  $s3->mb;
};

after all => sub {
  $s3->rm('/',"--recursive");
  $s3->rb;
};

sub put_s3_files {
  my $tmpfh = File::Temp->new();
  print $tmpfh "test";

  foreach my $file (@_) {
    $s3->s3api('put-object',
      '--key',$file,
      '--body',$tmpfh->filename);
  }

  $tmpfh->close;
}

