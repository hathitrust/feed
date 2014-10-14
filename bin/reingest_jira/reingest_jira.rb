require 'rest_client'
require 'json'
require 'yaml'
require 'sequel'
require 'pry'

JIRA_URL = "https://wush.net/jira/hathitrust/rest/api/2/"
GRIN_URL = "https://books.google.com/libraries" 

class GRIN

  def initialize(instance)
    @resource = RestClient::Resource.new("#{GRIN_URL}/#{instance}/")
  end

  def item(barcode)
    return
    Hash[@resource['_barcode_search'].get(:params => {:format => 'text', 
                                          :mode => 'full', 
                                          :execute_query => 'true', 
                                          :barcodes => barcode})
    .split("\n")
    .map { |x| x.split("\t") }
    .transpose]
  end
end

class JiraService

  def initialize(url_base,username,password)
    @resource = RestClient::Resource.new(url_base, :user => username, password: password)
  end

  def issue(issue_id) 
    return JiraTicket.new(JSON.parse(@resource["issue/#{issue_id}"].get),@resource)
  end

  def search(jql)
    puts "Finding issues with #{jql}"
    return JSON.parse(@resource['search'].get(:params => {:jql => jql, :maxResults => '1000'}))['issues'].map { |x| JiraTicket.new(@resource,x) }
  end
end

class WatchedItemsDB

  def initialize(dbh)
    @dbh = dbh
  end

  def get(item)
    return @dbh.fetch("select * from feed_watched_items where namespace = ? and id = ?",item.namespace,item.objid).first
  end

  def insert(item)
    @dbh['insert into feed_watched_items (namespace, id) values (?, ?)',item.namespace,item.objid].insert
  end

  def grin_instance(namespace)
     fetch('select grin_instance from ht_namespaces where namespace = ?',namespace).first
  end

  def table_has_item?(item,table)
    @dbh.fetch("select namespace, id from #{table} where namespace = ? and id = ?",item.namespace,item.objid) do |row|
      # had any rows? return true
      return true
    end
    return false
  end

end

class JiraTicket

  def initialize(ticket,service)
    @ticket = ticket
    @service = service
    raise "No database connection initialized" if(not @@db)
  end

  def items
    return customfield('10040').split(/\s*[;\n]\s*/m).map { |url| HTItem.new(url) }
  end

  def process
  end

  private

  def customfield(field_id)
    return @ticket['fields']["customfield_#{field_id}"]
  end
end

class HTItem
  attr_reader :objid
  attr_reader :namespace

  def self.set_watchdb(db)
    @@db = db
  end
  
  def initialize(item_url)
    # Try to extract ID from item ID
    if item_url =~ /babel.hathitrust.org.*id=(.*)/
      item_id = $1;
    elsif item_url =~ /hdl.handle.net\/2027\/(.*)/
      item_id = $1;
    else
      item_id = item_url
    end

    if item_id =~ /(\w{0,4})\.(.*)/
      @namespace = $1
      @objid = $2
    else
      raise "Can't parse item_url"
    end

    # try to get info from mysql
    get_watch_info
  end

  def table_has_item?(table)
    return @@db.table_has_item?(self,table)
  end

  def grin_instance
    namespace_info = @@db.grin_instance(namespace)

    if(namespace_info)
      grin_instance = namespace_info[:grin_instance]
      if(grin_instance)
        return grin_instance
      else
        raise "Reingest is only supported for Google ingest"
      end
    else
      raise "Unknown namespace #{@namespace}"
    end

  end

  def watch

    if watched?
      raise "Item is already watched"
    end

    if table_has_item?('feed_blacklist') 
      raise "Item is blacklisted"
    end

    grin_instance = self.grin_instance

    if not (table_has_item?('feed_queue') or table_has_item?('feed_nonreturned') or table_has_item?('rights_current'))
      raise "Item has no bib data in Zephir"
    end

    @@db.insert(self)
  end

  def watched?
    return @is_watched
  end

  def get_watch_info()
    watch_info = @@db.get(self)
    if(watch_info)
      @is_watched = true
    else
      @is_watched = false
    end
  end

end
