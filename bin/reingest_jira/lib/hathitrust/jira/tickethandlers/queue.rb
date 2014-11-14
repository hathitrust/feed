module HathiTrust
  class QueueHandler < JiraTicketHandler
    MAX_QUEUE_WAIT = 14

    def next_steps(items)
      if(items.all? { |item| item.ready? or item_stuck?(item) })
        @comment = item_statuses(items)
        return "UM to investigate further"
      elsif(items_queued?(items))
        return "HT to reingest"
      end
    end

    def item_status(item)
      # does whatever needs to happen for item if ticket is ready to progress
      item_stuck_or_ready_message(item,"waiting to be queued")
    end

    def item_stuck?(item)
      return (not item.queued? and item.request_age > MAX_QUEUE_WAIT)
    end

  end
end
