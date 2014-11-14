require 'hathitrust'
require 'hathitrust/jira/tickethandlers'
require 'hathitrust/jira/ticket'
require 'json'

module HathiTrust
  JIRA_URL = "https://wush.net/jira/hathitrust/rest/api/2/"

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

end
