use strict;
use warnings;

require "$ENV{FEED_HOME}/bin/audit/crawl_repo_mets.pl";

use Data::Dumper;
use File::Copy;
use File::Pairtree qw(id2ppath s2ppchars);
use File::Spec;
use Test::Spec;

use HTFeed::DBTools qw(get_dbh);
use HTFeed::Storage::LocalPairtree;


describe "bin/audit/crawl_repo_mets.pl" => sub {

  # crawl_repo_mets.pl reconfigures this in a way that breaks the test logger;
  # set it back
  use HTFeed::Log {root_logger => 'TRACE, string, screen'};
  spec_helper 'storage_helper.pl';
  local our ($tmpdirs, $testlog);

  sub run_audit {
    @ARGV = @_;
    main();
  }
  
  sub stage_item {
    my $zip = shift;
    my $mets = shift;
  
    my $repo_root = $tmpdirs->{obj_dir};
    my $item_dir = "$repo_root/sdr1/obj/test/pairtree_root/te/st/test";
  
    my $fetch_dir = get_config('staging','fetch');
  
    system("mkdir -p $item_dir");
    system("cp -f $fetch_dir/$zip $item_dir/test.zip");
    system("cp -f $fetch_dir/$mets $item_dir/test.mets.xml");
  
  }

  it "records a first ingest date in feed_audit" => sub {
    stage_item('test.zip','test-oneingest.mets.xml');

    run_audit("--mets",$tmpdirs->{obj_dir});

    my $first_ingest_date = get_dbh()->selectrow_arrayref("SELECT date(first_ingest_date) FROM feed_audit WHERE namespace = 'test' and id = 'test'")->[0];
    is($first_ingest_date, '2012-10-09');
  };

  it "records the earlier ingest date if there are two in the mets" => sub {
    stage_item('test.zip','test-twoingests.mets.xml');
    run_audit("--mets",$tmpdirs->{obj_dir});

    my $first_ingest_date = get_dbh()->selectrow_arrayref("SELECT date(first_ingest_date) FROM feed_audit WHERE namespace = 'test' and id = 'test'")->[0];
    is($first_ingest_date, '2012-10-09');
  };

  it "outputs OCR date" => sub {
    stage_item('test-googlemets.zip','test-googlemets.mets.xml');
    my $tmp_str = "";

    {
      # temporarily reopen stdout to output to $tmp_str
      open(my $tmp_out, ">", \$tmp_str);
      local *STDOUT = $tmp_out;
      run_audit("--src_mets",$tmpdirs->{obj_dir});
    }

    ok($tmp_str =~ /SRC_METS_PREMIS_EVENT\tOCR\t2025-09-10/m)
  };
};

runtests unless caller;
