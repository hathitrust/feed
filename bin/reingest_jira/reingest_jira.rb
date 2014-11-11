require 'rest_client'
require 'json'
require 'yaml'
require 'sequel'
require 'pry'
require 'pairtree'

JIRA_URL = "https://wush.net/jira/hathitrust/rest/api/2/"
GRIN_URL = "https://books.google.com/libraries" 
ERROR_NEXT_STEPS = 'UM to investigate further'
DATE_FORMAT = "%Y-%m-%d"

class GRIN

  def initialize(instance)
    @resource = RestClient::Resource.new("#{GRIN_URL}/#{instance}/")
  end

  def item(barcode)
    return Hash[@resource['_barcode_search'].get(:params => {:format => 'text', 
                                                 :mode => 'full', 
                                                 :execute_query => 'true', 
                                                 :barcodes => barcode.upcase})
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

class RepositoryDB

  def initialize(dbh)
    @dbh = dbh
  end

  def get(item)
    return table_info(item,'feed_watched_items')
  end

  def table_info(item,table)
    return @dbh.fetch("select * from #{table} where namespace = ? and id = ?",item.namespace,item.objid).first
  end

  def queue_info(item)
    return @dbh.fetch("select datediff(CURRENT_TIMESTAMP,q.update_stamp) as age, q.status, q.update_stamp from feed_queue q where q.namespace = ? and q.id = ?",item.namespace,item.objid).first
  end

  def last_error_info(item)
    return table_info(item,'feed_last_error')
  end

  def insert(item,issue_key)
    @dbh['insert into feed_watched_items (namespace, id, issue_key) values (?, ?, ?)',item.namespace,item.objid,issue_key].insert
  end

  def grin_instance(namespace)
    fetch('select grin_instance from ht_namespaces where namespace = ?',namespace).first
  end

  def table_has_item?(table,item)
    @dbh.fetch("select namespace, id from #{table} where namespace = ? and id = ?",item.namespace,item.objid) do |row|
      # had any rows? return true
      return true
    end
    return false
  end

end

class JiraTicketHandler
  attr_reader :comment

  def initialize()
    @errors = []
    @message = nil
  end

  def check_item(item)
  end

  def item_status(item)
  end

  def next_steps(items)
    return nil
  end

  def item_ingest_status(item)
    message = ""
    if item.queue_status == 'done'
      message = "#{item}: #{item.format_grin_dates}; Ingested #{item.zip_date.strftime(DATE_FORMAT)}\n" +
      "#{item}: #{item.grin_quality_info}"
    elsif item.queue_status == 'punted'
      message = "#{item}: failed ingest (#{item.last_error})"
      @errors.push(message)
    else 
      raise "item is ready but not done or punted??"
    end
    return message
  end

end

class ReingestHandler < JiraTicketHandler
  MAX_QUEUE_AGE = 7

  def next_steps(items)
    if items.all? { |item| item.ready? or item_stuck?(item) }
      # generate report
      @comment = items.map { |item| item_status(item) }.join("\n")
      return "UM to investigate further"
    else 
      return nil
    end
  end

  def check_item(item)
    # makes sure invariants still hold
    raise "#{item}: Next steps are HT to reingest but item is not in queue" if not item.queued?
  end

  def item_status(item)
    # does whatever needs to happen for item if ticket is ready to progress
    message = ""
    if item_stuck?(item)
      message = "#{item}: #{item.why_stuck}"
      @errors.push(message)
    elsif item.ready?
      message = item_ingest_status(item)
    else
      raise "item not ingested or stuck??"
    end

    return message
  end

  def item_stuck?(item)
    return (item.queued? and item.queue_age > MAX_QUEUE_AGE)
  end

end

class QueueHandler < JiraTicketHandler
  MAX_QUEUE_WAIT = 14

  def next_steps(items)
    if(items.all? { |item| item.ready? or item_stuck?(item) })
      @comment = items.map { |item| item_status(item) }.join("\n")
      return "UM to investigate further"
    elsif(items.all? { |item| item.in_table?('feed_queue') })
      return "HT to reingest"
    end
  end

  def item_status(item)
    # does whatever needs to happen for item if ticket is ready to progress
    message = ""
    if item_stuck?(item)
      message = "#{item}: stuck - waiting to be queued"
      @errors.push(message)
    elsif item.ready?
      message = item_ingest_status(item)
    else
      # do nothing - still waiting to be queued
    end

    return message
  end

  def item_stuck?(item)
    return (not item.in_table?('feed_queue') and item.request_age > MAX_QUEUE_WAIT)
  end
end

class ReanalyzeHandler < JiraTicketHandler
end

class ReprocessHandler < JiraTicketHandler
end

class RescanHandler < JiraTicketHandler
end

class DefaultHandler < JiraTicketHandler
  def item_stuck?(item)
    return false
  end
end

class JiraTicket

  attr_reader :items

  @@ticket_processors = { 
    'HT to reingest' => ReingestHandler,
    'HT to queue' => QueueHandler,
    'Google to reanalyze' => ReanalyzeHandler,
    'Google to re-process' => ReprocessHandler,
    'UM to scan entire book' => RescanHandler
  }

  def initialize(ticket,service)
    @ticket = ticket
    @service = service
    @items = customfield('10040').split(/\s*[;\n]\s*/m).map { |url| JiraTicketItem.new(url) }
  end

  def next_steps
    return customfield('10020')
  end

  def process
    processor_class = @@ticket_processors[next_steps]
    if(processor_class)
      processor = processor_class.new()
    else 
      processor = DefaultHandler.new()
    end

    watch_items

    begin

      # enforce invariants
      items.each { |item| processor.check_item(item) }

      # add comment iff changing next steps
      if(next_steps = processor.next_steps(items))
        set_next_steps(next_steps)
        add_comment(processor.comment)
      end

    rescue RuntimeError => e
      add_comment("Unexpected error: #{e.message}")
      set_next_steps(ERROR_NEXT_STEPS)
    end

  end

  def key
    return @ticket['key']
  end

  private

  def customfield(field_id)
    return @ticket['fields']["customfield_#{field_id}"]
  end

  def add_comment(comment)
    @service["issue/#{key}/comment"].post({ 'body' => comment }.to_json, :content_type => :json)
  end

  def set_next_steps(next_steps)
    update({ 'fields' => 
           { 'customfield_10020' => { 'value' => next_steps }  }
    })
  end

  def update(update_spec)
    @service["issue/#{key}"].put(update_spec.to_json, :content_type => :json)
  end

  def watch_items
    items.each { |item| item.watch(key) if not item.watched? }
  end
end

class HTItem
  attr_reader :objid
  attr_reader :namespace

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
  end

  def to_s
    return "#{namespace}.#{objid}"
  end

  def zip_date
    if path = zip_path 
      return File.stat(path).mtime.to_datetime
    else 
      return nil
    end
  end

  def zip_age
    return DateTime.now - zip_date
  end

  def zip_path
    pt = Pairtree.at("/sdr1/obj/#{namespace}")
    begin
      return pt["#{namespace}.#{objid}"].to_path + "/#{objid}.zip"
    rescue Errno::ENOENT
      return nil
    end
  end

  def in_repository?
    return File.exists?(zip_path)
  end
end

class QueueItem < HTItem
  def self.set_watchdb(db)
    @@db = db
  end


  def in_table?(table)
    return @@db.table_has_item?(table,self)
  end

  def queued?
    return !! @@db.queue_info(self)
  end

  def queue_age
    return if_not_nil(@@db.queue_info(self),:age)
  end

  def queue_status
    return if_not_nil(@@db.queue_info(self),:status)
  end

  def queue_last_update
    return if_not_nil(@@db.queue_info(self),:update_stamp)
  end

  def last_error
    my_error_info = @@db.last_error_info(self)
    if my_error_info[:detail] == 'Unexpected GRIN state' and my_error_info[:message] == 'GRIN could not convert book' 
      return "conversion failure"
    else
      return "unknown"
    end
  end

  protected

  def if_not_nil(hash,sym)
    if(hash)
      return hash[sym]
    else
      return nil
    end
  end

end

class GRINItem < QueueItem

  def initialize(item_url)
    super(item_url)
    grin_info
  end

  def grin_info
    namespace_info = @@db.grin_instance(namespace)

    if(namespace_info)
      grin_instance = namespace_info[:grin_instance]
      if(grin_instance)
        return GRIN.new(grin_instance).item(@objid)
      else
        raise "#{self}: reingest is only supported for Google ingest"
      end
    else
      raise "#{self}: unknown namespace #{@namespace}"
    end

  end
end


class JiraTicketItem < GRINItem

  def ready?
    return !! if_not_nil(@@db.get(self),:ready)
  end

  def watch(issue_key)

    if watched?
      raise "#{self} is already watched"
    end

    if in_table?('feed_blacklist') 
      raise "#{self} is blacklisted"
    end

    if not (in_table?('feed_queue') or in_table?('feed_nonreturned') or in_table?('rights_current'))
      raise "#{self} has no bib data in Zephir"
    end

    @@db.insert(self,issue_key)
  end

  def watched?
    return !! @@db.get(self)
  end


  def request_age
    request_date = if_not_nil(@@db.get(self),:request_date)
    if(request_date)
      return (Time.new() - request_date) / 86400
    else
      return nil
    end
  end

  def grin_quality_info
    this_grin_info = grin_info
    raise "Not in GRIN" if not grin_info
    audit = this_grin_info['Audit']
    rubbish = this_grin_info['Rubbish']
    overall_error = this_grin_info['Overall Error%']
    material_error = this_grin_info['Material Error%']

    audit = "(not audited)" if not audit or audit.empty?
    rubbish = "(not evaluated)" if not rubbish or rubbish.empty?

    return "Audit: #{audit}; Rubbish: #{rubbish}; Material Error: #{material_error}; Overall Error: #{overall_error}"
  end

  def format_grin_dates
    this_grin_info = grin_info
    raise "Not in GRIN" if not this_grin_info
    # get only the dates, then remove ' Date' from the end, then sort by the actual dates.
    return ['Scanned','Processed','Analyzed','Converted','Downloaded'].map do |event| 
      grin_date = this_grin_info["#{event} Date"]
      grin_date == '' ? "never #{event}" : "#{event} #{Date.parse(grin_date).strftime(DATE_FORMAT)}"
    end.join("; ")
  end


  def why_stuck
    message = queue_status
    case message
    when 'in_process'
      message = 'in process'
    when 'rights'
      message = 'waiting for rights'
    when 'collated'
      message = 'waiting for rights'
    end
    return "stuck - #{message} since #{queue_last_update.strftime(DATE_FORMAT)}"
  end

end

