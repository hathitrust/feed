module HathiTrust
  class ReanalyzeHandler < DateChangeHandler
    MAX_QUEUE_WAIT = 7

    def initialize(ticket)
      super(ticket)
      @request_date = ticket.reanalyze_request_date
      raise ArgumentError.new("Missing reanalyze request date") if not @request_date
    end

    def next_steps(items)
      if(items.all? { |item| item.ready? or item_stuck?(item) } )
        @comment = item_statuses(items)
        return "UM to investigate further"
      elsif(items_queued?(items))
        return "HT to reingest"
      elsif(items.all? { |item| item.analyzed_since(@request_date) })
        @comment = item_statuses(items)
        return "HT to queue"
      end
    end

    def item_status(item)
      item_stuck_or_ready_message(item,"still waiting for reanalysis")
    end

    def item_stuck?(item)
      return (not item.analyzed_since(@request_date) and ticket.days_since_comment > MAX_QUEUE_WAIT)
    end
  end
end
