module HathiTrust
  class JiraTicketHandler
    attr_reader :comment
    attr_reader :ticket

    def initialize(ticket)
      @errors = []
      @message = nil
      @ticket = ticket
    end

    def check_item(item)
    end

    def item_status(item)
    end

    def item_statuses(items)
      items.map { |item| item_status(item) }.join("\n")
    end

    def items_queued?(items)
      items.all? { |item| item.in_table?('feed_queue') }
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

    def item_stuck_or_ready_message(item,message)
      if item_stuck?(item)
        @errors.push("#{item}: #{message}")
      else
        item_ingest_status(item)
      end
    end

  end

  class DefaultHandler < JiraTicketHandler
    def item_stuck?(item)
      return false
    end
  end
end
