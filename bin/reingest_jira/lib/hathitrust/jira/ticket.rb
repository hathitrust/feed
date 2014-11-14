module HathiTrust
  ERROR_NEXT_STEPS = 'UM to investigate further'
  DATE_FORMAT = "%Y-%m-%d"

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

    def reanalyze_request_date
      return DateTime.parse(customfield('10071'))
    end

    def reprocess_request_date
      return DateTime.parse(customfield('10070'))
    end

    def process

      begin
        processor_class = @@ticket_processors[next_steps]
        if(processor_class)
          processor = processor_class.new(self)
        else 
          processor = DefaultHandler.new(self)
        end

        watch_items

        # enforce invariants
        items.each { |item| processor.check_item(item) }

        # add comment iff changing next steps
        if(next_steps = processor.next_steps(items))
          set_next_steps(next_steps)
          add_comment(processor.comment)
        end

      rescue ArgumentError => e
        add_comment(e.message)
        set_next_steps(ERROR_NEXT_STEPS)
      rescue RuntimeError => e
        add_comment("Unexpected error: #{e.message}")
        set_next_steps(ERROR_NEXT_STEPS)
      end

    end

    def key
      return @ticket['key']
    end

    def last_comment_time
      return DateTime.parse(comments.sort { |a,b| a['created'] <=> b['created'] }[-1]['created'])
    end

    def days_since_comment
      return DateTime.now - last_comment_time
    end

    def comments
      return @ticket['fields']['comment']['comments']
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

end
