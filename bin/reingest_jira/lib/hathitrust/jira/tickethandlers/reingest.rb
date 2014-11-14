module HathiTrust

  class ReingestHandler < JiraTicketHandler
    MAX_QUEUE_AGE = 7

    def next_steps(items)
      if items.all? { |item| item.ready? or item_stuck?(item) }
        @comment = item_statuses(items)
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

end
