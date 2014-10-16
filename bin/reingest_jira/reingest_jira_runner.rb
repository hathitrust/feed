require_relative "reingest_jira"
require "pry"

config = YAML.load_file(ENV['HTFEED_CONFIG'])
db_config = config['mysql']
raise "Missing mysql configuration in #{ENV['HTFEED_CONFIG']}" if not db_config
db_user = db_config['username']
raise "Missing mysql username in #{ENV['HTFEED_CONFIG']}" if not db_user
db_pass = config['database_password']
raise "Missing database_password in #{ENV['HTFEED_CONFIG']}" if not db_pass

db = WatchedItemsDB.new( Sequel.connect(:adapter => 'mysql2',
                                        :host => 'mysql-sdr',
                                        :username => db_user,
                                        :password => db_pass,
                                        :database => 'aelkiss_ht'))

HTItem.set_watchdb(db)
binding.pry
