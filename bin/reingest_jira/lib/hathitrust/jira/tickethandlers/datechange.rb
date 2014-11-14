module HathiTrust
  class DateChangeHandler < JiraTicketHandler
  end

  class ReprocessHandler < DateChangeHandler
  end
  
  class RescanHandler < DateChangeHandler
  end
end
