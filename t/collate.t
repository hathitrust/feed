use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Spec;
use HTFeed::Test::Support qw(load_db_fixtures);
use HTFeed::Test::SpecSupport;
use HTFeed::Config qw(set_config get_config);
use HTFeed::DBTools qw(get_dbh);

describe "HTFeed::Collate" => sub {

  context "with mocked storage" => sub {
    context "when prevalidation fails" => sub {
      it "doesn't move to object storage";
    };

    context "when postvalidation fails" => sub {
      it "rolls back to the existing version";
      it "does not record an audit";
    };

    context "when move raises an exception" => sub {
      it "calls rollback";
    };

    context "when everything succeeds" => sub {
      it "commits";
      it "records an audit";
      it "reports stage success";
    }
  };

  context "with local pairtree" => sub {
    it "collates the zip and mets";
    it "records in feed_audit";

    context "when item exists in the repository" => sub {
      it "logs a repeat";
    };
  };

  context "with versioned pairtree" => sub {
    it "collates the zip and mets";
    it "records in feed_backups";
  };
};

runtests unless caller;
