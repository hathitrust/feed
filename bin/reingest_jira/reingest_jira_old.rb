#!/usr/bin/ruby

require 'rest_client'
require 'json'
require 'pry'
require 'date'
require 'pairtree'
require 'mysql2'

$jira_url = "https://wush.net/jira/hathitrust/rest/api/2/"
$grin_url = "https://books.google.com/libraries" 

# TODO: get parameters from config
# TODO: Use Sequel
$mysql = Mysql2::Client.new(:host => "mysql-sdr",
                            :username => "",
                            :password => "", 
                            :database => "ht",
                            :reconnect => true)

class GRIN

  def initialize(instance)
    @resource = RestClient::Resource.new("#{$grin_url}/#{instance}/")
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


class JiraTicket
  attr_reader :ticket

  def initialize(resource,ticket)
    @resource = resource
    @ticket = ticket
  end

  def comments
    return ticket['fields']['comment']['comments']
  end

  def last_comment_time
    return DateTime.parse(comments.sort { |a,b| a['created'] <=> b['created'] }[-1]['created'])
  end

  def create_date
    return DateTime.parse(ticket['fields']['created'])
  end

  def days_since_created
    return DateTime.now - create_date
  end

  def days_since_comment
    return DateTime.now - last_comment_time
  end

  def customfield(field_id)
    return ticket['fields']["customfield_#{field_id}"]
  end

  def next_steps
    return customfield('10020')
  end

  def reprocess_request_date
    return customfield('10070')
  end

  def reanalyze_request_date
    return customfield('10071')
  end

  def items
    return customfield('10040').split(/\s*[;\n]\s*/m).map { |url| HTItem.new(url) }
  end

  def key
    return ticket['key']
  end

  def labels
    return ticket['fields']['label']
  end

  def has_label?(label)
    return labels.include?(label)
  end

  def issue_id
    return ticket['key']
  end

  def update(update_spec)
    @resource["issue/#{issue_id}"].put(update_spec.to_json, :content_type => :json)
  end

  def set_next_steps(next_steps)
    update({ 'fields' => 
           { 'customfield_10020' => { 'value' => next_steps }  }
    })
  end

  def add_comment(comment)
    @resource["issue/#{issue_id}/comment"].post({ 'body' => comment }.to_json, :content_type => :json)
  end

  def add_label(label)
    update( { 'update' => { 
      'labels' => [ { 'add' => label } ] 
    } })
  end

  def process(handler,next_step_good,next_step_error)
    puts "Working on #{key}"

    # TODO: catch exceptions per-item and overall
    results = items.map { |item| handler(self,item) }

    # report/progress items only if ALL items are ready for it
    if results.all? { |r| r.report } 
      # progress items in queue
      results.each { |r| r.commit_queue }

      # set next steps
      if( results.any? { |r| r.error } or results.none? { |r| r.success } )
        set_next_steps(next_steps_error)
      else 
        set_next_steps(next_steps_good)
      end

      # add the comments
      add_comment(results.map { |r| r.comment }.join("\n"))

      # TODO: return some kind of issue summary

    end
  end

end

class ItemProcessResult
  # Is the item ready to have the ticket updated?
  attr_accessor :report
  # Was there an error handling the item?
  attr_accessor :error
  # Did the item progress successfully from one state to another?
  attr_accessor :success

  def initialize(item,report,error,success)
    @report = report
    @error = error
    @success = success
    @comment = []
  end

  def add_comment(new_comment)
    comment.push("#{item.namespace}.#{item.id}: #{new_comment}")
  end

  # Text to use when updating the ticket
  def comment
    return comment.join("\n")
  end
end

class HTItem
  attr_reader :objid
  attr_reader :namespace
  attr_reader :grin_info
  attr_reader :queue_age
  attr_reader :queue_status

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

    (@queue_age,@queue_status,@queue_update_time) = $mysql.query("select datediff(CURRENT_TIMESTAMP,q.update_stamp) as age, q.status, q.update_stamp from feed_queue q where q.namespace = '#{$mysql.escape(namespace)}' and q.id = '#{$mysql.escape(objid)}';", :as => :array).first

    @grin_info = grin_instance(namespace).item(objid)
  end

  def scan_date
    return DateTime.parse(grin_info['Scanned Date'])
  end

  def process_date
    return DateTime.parse(grin_info['Processed Date'])
  end

  def analyze_date
    return DateTime.parse(grin_info['Analyzed Date'])
  end

  def convert_date
    return DateTime.parse(grin_info['Converted Date'])
  end

  def download_date
    return DateTime.parse(grin_info['Downloaded Date'])
  end

  def grin_state
    return grin_info['State']
  end

  def last_error
    raise "UNIMPLEMENTED"
  end

  def queue_update_date
    return @queue_update_time.to_datetime
  end

  def zip_date
    if path = zip_path 
      return File::Stat.new.mtime.to_datetime
    else 
      return nil
    end
  end

  def zip_age
    return DateTime.now - zip_date
  end

  def zip_path
    pt = Pairtree.at('/sdr1/obj/#{namespace}')
    begin
      return pt['#{namespace}.#{objid}'].to_path + "/#{objid}.zip"
    rescue Errno::ENOENT
      return nil
    end
  end

  def in_repos?
    return File.exists?(zip_path)
  end

  def queue
    raise "UNIMPLEMENTED"
#    my $blacklist_sth = $dbh->prepare("SELECT namespace, id FROM feed_blacklist WHERE namespace = ? and id = ?");
#    my $digifeed_sth = $dbh->prepare("SELECT namespace, id FROM feed_mdp_rejects WHERE namespace = ? and id = ?");
#    my $has_bibdata_sth = $dbh->prepare("SELECT namespace, id FROM feed_queue WHERE namespace = ? and id = ? UNION SELECT namespace, id FROM feed_nonreturned WHERE namespace = ? and id = ? UNION SELECT namespace, id FROM rights_current WHERE namespace = ? and id = ?");
    # namespace and pkg_type already checked when initializing item & getting GRIN info
    blacklisted = not $mysql.query("select namespace, id from feed_backlist where namespace = '#{$mysql.escape(namespace)}' and id = '#{$mysql.escape(objid)}';", :as => :array).empty?
    is_digifeed = not $mysql.query("select namespace, id from feed_mdp_rejects where namespace = '#{$mysql.escape(namespace)}' and id = '#{$mysql.escape(objid)}';", :as => :array).empty?
    has_bibdata = not $mysql.query("select namespace, id from feed_queue where namespace = '#{$mysql.escape(namespace)}' and id = '#{$mysql.escape(objid)}'
                                   select namespace, id from feed_queue where namespace = '#{$mysql.escape(namespace)}' and id = '#{$mysql.escape(objid)}'
                                   
                                   ;", :as => :array).empty?

    # barcode OK?
    # pkg type (check HT namespace table?)
    # has bib data?
    # not blacklisted
    # if already queued - report on status
  end

  def check_grin
    raise "UNIMPLEMENTED"
  end

  def is_watched?(
      return $mysql.query("select namespace, id from feed_watched_items where namespace = '#{$mysql.escape(namespace)}' and id = '#{$mysql.escape(objid}'");

  def watch_item(needs_rescan,needs_reanalyze,needs_reprocess,request_date)
      # in_queue = self.in_queue?
      # if in queue & needs_rewhatever -- has been rewhatevered since request date?

      # insert into feed_watched_items values namespace, id, needs_rescan, needs_reanalyze, needs_reprocess, request_date
  end

end

def requeue_handler(ticket,item)
  # default: report, no error, no success
  result = ItemProcessResult.new(item,true,false,false)

  # TODO: is the item already in the queue? if so, was it progressed since the item was set to 'HT to queue'?

  try_queue = false
  if not item.in_repos?
    try_queue=true
    result.add_comment("not previously ingested")
  end

  if item.analyze_date > item.convert_date
    if item.grin_state == 'CONVERTED' or item.grin_state == 'IN_PROCESS'
      result.add_comment("has been reanalyzed or reprocessed since it was last converted, but its GRIN state is currently #{item.grin_state}. Waiting for expiration.")
    else
      result.add_comment("has been reanalyzed or reprocessed since it was last converted")
      try_queue = true
    end
  elsif item.analyze_date > item.download_date
    result.add_comment("has been reanalyzed or reprocessed since it was last downloaded")
    try_queue = true
  else
    



end

def reingest_handler(ticket,item)
  # default: report, no error, success
  result = ItemProcessResult.new(item,true,false,true)

  in_queue = item.queue_age?
  # get queue status - if done or not in queue, probably reingested
  if item.queue_status == 'done' or not in_queue
    # not in repository
    if not item.in_repos? 
      result.add_comment("is not in the repository")
    elsif item.zip_date < ticket.create_date  # FIXME - use date item was queued?
      result.add_comment("was not reingested")
    elsif item.zip_age < 1 
      # wait to report -- zip not yet synched
      result.report = 0 
    else
      # ingested and synched; report
      grin_info = item.grin_info
      result.add_comment("ingested; zip file date #{item.zip_date}")
      result.add_comemnt("Audit: #{grin_info['Audit']}; Rubbish: #{grin_info['Rubbish']}")
      result.add_comment("Material Error: #{grin_info['Material Error%']} Overall Error: #{grin_info['Overall Error%']}")
    end
  elsif item.queue_status == 'punted' 
    # failed ingest
    result.add_comment("failed ingest")
    result.add_comment(item.last_error)
  elsif item.queue_age > 7  
    # in queue a long time - why?
    if item.queue_status == 'in_process'
      result.add_comment("stuck in process since #{item.queue_update_date}")
    elsif item.queue_status == 'rights'
      result.add_comment("waiting for rights since #{item.queue_update_date}")
    else 
      result.add_comment("unexpectedly stuck in queue with status #{item.queue_status} since #{item.queue_update_date}")
    end
  else
    # wait to report on ticket -- still waiting for ingest. comment is for LITCS reporting
    result.report = 0
    result.add_comment("waiting for ingest; status is #{item.queue_status}; GRIN state is #{item.grin_state}")
  end

  return result

end

def grin_instance(namespace)
    result = $mysql.query("select grin_instance from ht_namespaces namespace = '#{$mysql.escape(namespace)}'", :as => :array).first
    if result
      return result[0]
    else
      raise "#{namespace} has no GRIN instance. Automated reingest only supports items returned through GRIN."
    end
end

svc = JiraService.new($jira_url,'aelkiss','27PxhHfD3L7t1hmpIge9U3m79g6tG8To')

issue = svc.issue('HTS-3046')
binding.pry

# svc.search('"Next Steps" = "Google to re-process" AND (labels IS NULL OR labels != "automation_ignore")').each do |issue| 
#   issue.process(reingest_handler,'HT to reingest','UM to investigate further')
# end

# TODO: search for items set to 'done' since last run, collate with all item IDs and update tickets. 
# Set last run flag after successful run

# TODO: monthly update of ingest status of items from specific attachment from tickets with some label
