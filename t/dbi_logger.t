use HTFeed::Log { root_logger => 'INFO, dbi, screen' };
use Log::Log4perl qw(get_logger);
use HTFeed::DBTools qw(get_dbh);
use Test::Spec;

describe "HTFeed::Log" => sub {
  sub first_log_row {
    get_dbh()->selectrow_arrayref("select message from feed_log");
  }

  before each => sub {
    get_dbh()->do("DELETE FROM feed_log");
  };

  it "does not log level INFO to DB" => sub {
    get_logger()->info("shouldn't be in db");

    ok(not defined first_log_row());
  };

  it "logs level ERROR to DB" => sub {
    get_logger()->error("message");

    is(first_log_row()->[0], "message");
  };

  # Same logging call as in HTFeed::Job::update
  it "logs collate succeeded message to DB" => sub {
    get_logger()->info('StageSucceeded', 
      namespace => "test", 
      objid => "test",
      stage => "HTFeed::Stage::Collate",
      detail => "repeat=1");

    is(first_log_row()->[0], "Stage succeeded");
  };

  it "does not log other stage succeeded message to DB" => sub {
    get_logger()->info('StageSucceeded', 
      namespace => "test", 
      objid => "test",
      stage => "HTFeed::Stage::Handle");

    ok(not defined first_log_row());
  }
};

runtests unless caller;
