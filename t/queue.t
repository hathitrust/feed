use Test::Spec;

use HTFeed::Config qw(get_config);
use HTFeed::QueueRunner;

use strict;

describe "HTFeed::FaktoryQueue" => sub {
  it "puts a ready item on the queue";
  it "changes ready status to queued";
};

describe "HTFeed::QueueRunner" => sub {
  it "runs jobs for items from the queue";
  it "updates the node in the database when getting an item";
  it "updates the status in the database for each job";
  it "reports success to faktory";
  it "reports failure to faktory";
};
