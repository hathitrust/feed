module HathiTrust
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
end
