require 'spec_helper'

JIRA_STUB_URL = "https://foo:bar@wush.net/jira/hathitrust/rest/api/2/issue/HTS-9999"
JIRA_COMMENT_URL = JIRA_STUB_URL + "/comment"

$stuck_queue_info = {:age=>341, :status=>"in_process", :update_stamp=>Time.new(2013,11,07,15,30,36,'-05:00')}

$punted_queue_info = {:age=>0, :status=>"punted", :update_stamp=>Time.new()}

$punted_last_error = {:level => 'ERROR', :timestamp => Time.new(), :namespace => 'mdp', 
  :id => '39015002276304', :operation => nil, :message => 'GRIN could not convert book', 
  :file  => nil, :field => 'grin_state', :actual => 'PREVIOUSLY_DOWNLOADED', :expected => 'CONVERTED', 
  :detail => 'Unexpected GRIN state', :stage => '/htapps/babel/feed/bin/feed.hourly/ready_from_grin.pl'}

$in_process_queue_info = {:age=>0, :status=>"in_process", :update_stamp=>Time.new()}

$ingested_queue_info = {:age=>0, :status=>"done", :update_stamp=>Time.new()}

$old_watched_item = {:namespace=>'mdp', :id=>'39015002276304',
  :needs_rescan=>false, :needs_reanalyze=>false, :needs_reprocess=>false,
  :request_date=>Time.new(2013,10,06,14,03,56,'-04:00'), :in_queue=>false,
  :queue_date=>nil, :ready=>true, :issue=>"0"}

$watched_item = {:namespace=>'mdp', :id=>'39015002276304',
  :needs_rescan=>false, :needs_reanalyze=>false, :needs_reprocess=>false,
  :request_date=>Time.new(2014,10,06,14,03,56,'-04:00'), :in_queue=>false,
  :queue_date=>nil, :ready=>true, :issue=>"0"}

$nonready_watched_item = {:namespace=>'mdp', :id=>'39015002276304',
  :needs_rescan=>false, :needs_reanalyze=>false, :needs_reprocess=>false,
  :request_date=>Time.new(2014,10,06,14,03,56,'-04:00'), :in_queue=>false,
  :queue_date=>nil, :ready=>false, :issue=>"0"}


RSpec.configure do |config|
  config.before(:each) do
    stub_request(:get, JIRA_STUB_URL).
      to_return(status: 200, body: File.new('spec/fixtures/hts-9999.json'), headers: {})

    stub_request(:post, JIRA_COMMENT_URL).
      to_return(:status => 200, :body => "", :headers => {})

    stub_request(:put, JIRA_STUB_URL).
      with(:body => /{"fields":{"customfield_10020":{"value":"[\w ]+"}}}/).
      to_return(:status => 200, :body => "", :headers => {})

    # accept any uppercase barcode
    stub_request(:get, /#{GRIN_URL}\/\w+\/_barcode_search\?barcodes=[A-Z\d$]+&execute_query=true&format=text&mode=full/).
      to_return(:status => 200, body: File.new("spec/fixtures/generic.grin.txt"), headers: {})


    stub_request(:get, "#{GRIN_URL}/UOM/_barcode_search").
      with(:query => {:format => 'text', 
           :mode => 'full', 
           :execute_query => 'true', 
           :barcodes => $watched_item[:id]}).
           to_return(:status => 200, body: File.new("spec/fixtures/#{$watched_item[:id]}.grin.txt"), headers: {})

  end

end

RSpec.describe JiraTicketItem do
  let(:db) { instance_double("HathiTrust::RepositoryDB") }

  before(:each) do
    allow(db).to receive(:get)
    allow(db).to receive(:queue_info)
    allow(db).to receive(:grin_instance).with('mdp').and_return({:grin_instance => 'UOM'})
    allow(db).to receive(:grin_instance).with('uc1').and_return({:grin_instance => 'UCAL'})
    allow(db).to receive(:grin_instance).with('yale').and_return({:grin_instance => nil})
    allow(db).to receive(:grin_instance).with('loc').and_return({:grin_instance => nil})
    allow(db).to receive(:grin_instance).with('foo').and_return(nil)
    allow(db).to receive(:table_has_item?).and_return(false)
    JiraTicketItem.set_watchdb(db)
  end

  describe '.new' do
    context 'when given an item handle' do
      let(:item) { JiraTicketItem.new('http://hdl.handle.net/2027/mdp.39015012345678') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('mdp') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq('39015012345678') 
      end
    end

    context 'when given a babel URL' do
      let(:item) { JiraTicketItem.new('http://babel.hathitrust.org/cgi/pt?id=uc1.$b281602') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('uc1') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq ('$b281602') 
      end
    end

    context 'when given a bare item ID' do
      let(:item) { JiraTicketItem.new('uc1.$b123456') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('uc1') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq('$b123456') 
      end
    end

    it 'throws an error for a garbage item URL' do
      expect { JiraTicketItem.new('wat is this garbage lol') }.to raise_error
    end
  end

  describe '#watch' do
    context 'when item has an unknown namespace' do
      it { expect { JiraTicketItem.new('foo.lakjdf').watch('HTS-9999') }.to raise_error(RuntimeError, /unknown namespace/i) }
    end

    context 'when item has a non-Google namespace' do
      it { expect { JiraTicketItem.new('loc.ark:/13960/t58d0dn7n').watch('HTS-9999') }.to raise_error(RuntimeError, /google/i) }
    end

    context 'when item is blacklisted' do
      it { 
        item = JiraTicketItem.new('mdp.39015005021392')
        expect(db).to receive(:table_has_item?).with('feed_blacklist',item).and_return(true)
        expect { item.watch('HTS-9999') }.to raise_error(RuntimeError, /blacklist/i) 
      }
    end

    context 'when item is missing bib data' do
      it { expect { JiraTicketItem.new('mdp.39015123456789').watch('HTS-9999') }.to raise_error(RuntimeError, /bib data/i) }
    end

    context 'when item has a Google namespace, bib data, and is in GRIN' do
      let(:item) { JiraTicketItem.new('mdp.35112104589306') }

      before(:each) do
        allow(db).to receive(:table_has_item?).with('feed_watched_items',item).and_return(false)
        allow(db).to receive(:table_has_item?).with('feed_blacklist',item).and_return(false)
        allow(db).to receive(:table_has_item?).with('feed_queue',item).and_return(false)
        allow(db).to receive(:table_has_item?).with('feed_nonreturned',item).and_return(false)
        allow(db).to receive(:table_has_item?).with('rights_current',item).and_return(true)
        allow(item).to receive(:grin_instance).and_return('UOM')
      end

    end

  end

  describe '#queue_age' do
    context 'when the item is in queue' do
      before(:each) { allow(db).to receive(:queue_info).and_return($stuck_queue_info) }
      let(:item) { JiraTicketItem.new('mdp.35112104589306') }

      it 'knows how long it has been in the queue' do
        expect(item.queue_age).to_not be(nil)
      end
    end
  end

  describe '#to_s' do
    it 'returns namespace.objid' do
      expected = 'mdp.35112104589306'
      item = JiraTicketItem.new(expected)
      expect(item.to_s).to eq(expected)
    end
  end

  describe '#format_grin_dates'  do
    it 'returns string of dates sorted by date' do
      expected = 'Scanned 2008-02-20; Processed 2008-02-20; Analyzed 2008-08-27; Converted 2013-11-21; Downloaded 2013-11-21'
      item = JiraTicketItem.new('mdp.35112104589306')
      expect(item.format_grin_dates).to eq(expected)
    end
  end
end


RSpec.describe JiraTicket do
  let(:db) { instance_double("HathiTrust::RepositoryDB") }
  let(:service) { JiraService.new(JIRA_URL,'foo','bar') }
  let(:ticket) { service.issue('HTS-9999') }

  before(:each) do
    JiraTicketItem.set_watchdb(db)
    allow(db).to receive(:queue_info)
    allow(db).to receive(:grin_instance).with('mdp').and_return({:grin_instance => 'UOM'})
    allow(db).to receive(:table_has_item?).and_return(false)
    allow(db).to receive(:table_has_item?).with('feed_nonreturned',anything()).and_return(true)
  end

  context 'when an item is not on the watch list' do
    before(:each) { allow(db).to receive(:get).and_return(nil) }

    it "is added to watch list" do
      expect(db).to receive(:insert)
      ticket.process
    end
  end

  context 'and all items are on watch list' do
    before(:each) { 
      allow(db).to receive(:table_has_item?).with('feed_watched_items',anything()).and_return(true) 
      allow(db).to receive(:get).and_return($watched_item)
    }

    ############## GOOGLE TO REANALYZE ###########################
    context 'when ticket has state Google to Reanalyze' do
      before(:each) { allow(ticket).to receive(:next_steps).and_return('Google to reanalyze') }

      # TODO: DRY THIS UP (from HT to queue)
      context 'and an item is not in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(false)  }

        context 'and it has been watched for more than one week' do
          before(:each) { allow(db).to receive(:get).and_return($old_watched_item) }

          it 'reports as stuck' do
            allow(db).to receive(:queue_info).and_return($stuck_queue_info)
            ticket.process
            expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{ticket.items.first.to_s}: .*stuck - waiting for analysis.*/ }
          end
        end

      end

      context 'and all items are in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(true) }
        context 'and an item is not ready' do
          before(:each) { allow(db).to receive(:get).and_return($nonready_watched_item) }

          context 'and it was reanalyzed' do
            before(:each) {raise "It was reanalayzed??"}
            it 'sets next steps to HT to reingest' do
              ticket.process
              expect(WebMock).to have_requested(:put, JIRA_STUB_URL).with { |req| req.body =~ /HT to reingest/ }
            end
          end

          context 'and it was not reanalyzed' do
            before(:each) {raise "It was not reanalayzed??"}
            it 'does not change next steps' do
              ticket.process
              expect(ticket).not_to receive(:set_next_steps) 
            end
          end
        end

        context 'and reingest was attempted for all items' do
          context 'and all items were reanalyzed' do
            it 'sets next steps to UM to investigate furhter' do
              ticket.process
              expect(WebMock).to have_requested(:put, JIRA_STUB_URL).with { |req| req.body =~ /UM to investigate further/ }
            end
          end

          context 'and an item was not reanalyzed' do
            it 'does not change next steps' do
              ticket.process
              expect(ticket).not_to receive(:set_next_steps) 
            end

            it 'comments on the ticket' do
              ticket.process
              expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{ticket.items.first.to_s}: .*not reanalyzed.*ingested.*/ }
            end
          end
        end
      end
    end

    ############## HT TO QUEUE ###########################
    context 'when ticket has state HT to queue' do
      before(:each) { allow(ticket).to receive(:next_steps).and_return('HT to queue') }

      context 'and all items are in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(true) }

        context 'and an item is not ready' do
          before(:each) { allow(db).to receive(:get).and_return($nonready_watched_item) }

          it 'sets next steps to HT to reingest' do
            ticket.process
            expect(WebMock).to have_requested(:put, JIRA_STUB_URL).with { |req| req.body =~ /HT to reingest/ }
          end
        end

        context 'and all items are ready' do
          it 'sets next steps to UM to investigate further' do
            allow(db).to receive(:queue_info).and_return($punted_queue_info)
            allow(db).to receive(:last_error_info).and_return($punted_last_error)
            ticket.process
            expect(WebMock).to have_requested(:put, JIRA_STUB_URL).with { |req| req.body =~ /UM to investigate further/ }
          end
        end

      end

      context 'and an item is not in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(false)  }

        context 'and it has been watched for more than two weeks' do
          before(:each) { allow(db).to receive(:get).and_return($old_watched_item) }

          it 'reports as stuck' do
            allow(db).to receive(:queue_info).and_return($stuck_queue_info)
            ticket.process
            expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{ticket.items.first.to_s}: .*stuck - waiting to be queued.*/ }
          end
        end

      end
    end


    ############## HT TO REINGEST ###########################
    context 'when ticket has state HT to reingest' do
      before(:each) { allow(ticket).to receive(:next_steps).and_return('HT to reingest') }

      context 'and all items are in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(true) }

        context 'and all items are ready' do
          before(:each) { ticket.items.each { |item| allow(item).to receive(:zip_date).and_return(Time.new(2014,10,13,11,36,52,'-05:00')) } }

          it 'sets next steps to UM to investigate further' do
            allow(db).to receive(:queue_info).and_return($punted_queue_info)
            allow(db).to receive(:last_error_info).and_return($punted_last_error)
            ticket.process
            expect(WebMock).to have_requested(:put, JIRA_STUB_URL).with { |req| req.body =~ /UM to investigate further/ }
          end

          context 'and items were successfully ingested' do
            before(:each) { allow(db).to receive(:queue_info).and_return($ingested_queue_info) }
            it 'reports scan/process/analyze/ingest date' do
              ticket.process
              expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{$watched_item[:namespace]}.#{$watched_item[:id]}: Scanned 2008-02-20; Processed 2008-02-20; Analyzed 2008-08-27; Converted 2013-11-21; Downloaded 2013-11-21; Ingested 2014-10-13/ }
            end

            it 'reports GRIN quality statistics' do
              ticket.process
              expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{$watched_item[:namespace]}.#{$watched_item[:id]}: Audit: \(not audited\); Rubbish: \(not evaluated\); Material Error: 0%; Overall Error: 2%/ }
            end

          end

          context 'and items were not successfully ingested' do
            before(:each) do
              allow(db).to receive(:queue_info).and_return($punted_queue_info) 
              allow(db).to receive(:last_error_info).and_return($punted_last_error)
            end

            it 'reports the last ingest error' do
              ticket.process
              expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{$watched_item[:namespace]}.#{$watched_item[:id]}: failed ingest \(conversion failure\)/ }
            end
          end

        end

        context 'and an item is not ready' do
          before(:each) { allow(db).to receive(:get).and_return($nonready_watched_item) }

          it 'and all items are enqueued more than a week, reports as stuck' do
            allow(db).to receive(:queue_info).and_return($stuck_queue_info)
            ticket.process
            expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /#{ticket.items.first.to_s}: .*stuck - in process.*/ }
          end

          it 'and enqueued less than a week, does not change next steps' do
            allow(db).to receive(:queue_info).and_return($in_process_queue_info)
            expect(ticket).not_to receive(:set_next_steps) 
            ticket.process
          end

        end

      end

      context 'and is not in the queue' do
        before(:each) do 
          allow(db).to receive(:table_has_item?).with('feed_queue',anything()).and_return(false) 
          allow(db).to receive(:queue_info).with(anything()).and_return(nil) 
        end

        it 'reports that the item has disappeared from the queue' do
          ticket.process
          expect(WebMock).to have_requested(:post, JIRA_COMMENT_URL).with { |req| req.body =~ /not in queue/i }
        end
      end
    end


  end

end
