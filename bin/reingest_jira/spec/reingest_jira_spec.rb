require_relative '../reingest_jira'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

$jira_stub_url = "https://foo:bar@wush.net/jira/hathitrust/rest/api/2/issue/HTS-9999"
$jira_comment_url = $jira_stub_url + "/comment"

# DRY this up with FactoryGirl????
$stuck_queue_info = {:age=>341, :status=>"in_process", :update_stamp=>Time.new(2013,11,07,15,30,36,'-05:00')}
$punted_queue_info = {:age=>0, :status=>"punted", :update_stamp=>Time.new()}
$in_process_queue_info = {:age=>0, :status=>"punted", :update_stamp=>Time.new()}
$ingested_queue_info = {:age=>0, :status=>"done", :update_stamp=>Time.new()}

$watched_item = {:namespace=>'mdp', :id=>'39015002276304',
  :needs_rescan=>false, :needs_reanalyze=>false, :needs_reprocess=>false,
  :request_date=>Time.new(2014,10,06,14,03,56,'-04:00'), :in_queue=>false,
  :queue_date=>nil, :ready=>true, :issue=>"0"}

$nonready_watched_item = {:namespace=>'mdp', :id=>'39015002276304',
  :needs_rescan=>false, :needs_reanalyze=>false, :needs_reprocess=>false,
  :request_date=>Time.new(2014,10,06,14,03,56,'-04:00'), :in_queue=>false,
  :queue_date=>nil, :ready=>false, :issue=>"0"}


RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  config.before(:each) do
    stub_request(:get, $jira_stub_url).
      to_return(status: 200, body: File.new('hts-9999.json'), headers: {})

    stub_request(:post, $jira_stub_url + "/comment").
      to_return(:status => 200, :body => "", :headers => {})

    stub_request(:put, $jira_stub_url).
      with(:body => /{"fields":{"customfield_10020":{"value":"[\w ]+"}}}/).
      to_return(:status => 200, :body => "", :headers => {})

    # accept any uppercase barcode
    stub_request(:get, /#{GRIN_URL}\/\w+\/_barcode_search\?barcodes=[A-Z\d$]+&execute_query=true&format=text&mode=full/).
           to_return(:status => 200, body: File.new("generic.grin.txt"), headers: {})
        

    stub_request(:get, "#{GRIN_URL}/UOM/_barcode_search").
      with(:query => {:format => 'text', 
           :mode => 'full', 
           :execute_query => 'true', 
           :barcodes => $watched_item[:id]}).
           to_return(:status => 200, body: File.new("#{$watched_item[:id]}.grin.txt"), headers: {})

  end

end

RSpec.describe HTItem do
  let(:db) { instance_double("WatchedItemsDB") }

  before(:each) do
    allow(db).to receive(:get)
    allow(db).to receive(:queue_info)
    allow(db).to receive(:grin_instance).with('mdp').and_return({:grin_instance => 'UOM'})
    allow(db).to receive(:grin_instance).with('uc1').and_return({:grin_instance => 'UCAL'})
    allow(db).to receive(:grin_instance).with('yale').and_return({:grin_instance => nil})
    allow(db).to receive(:grin_instance).with('loc').and_return({:grin_instance => nil})
    allow(db).to receive(:grin_instance).with('foo').and_return(nil)
    allow(db).to receive(:table_has_item?).and_return(false)
    HTItem.set_watchdb(db)
  end

  describe '.new' do
    context 'when given an item handle' do
      let(:item) { HTItem.new('http://hdl.handle.net/2027/mdp.39015012345678') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('mdp') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq('39015012345678') 
      end
    end

    context 'when given a babel URL' do
      let(:item) { HTItem.new('http://babel.hathitrust.org/cgi/pt?id=uc1.$b281602') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('uc1') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq ('$b281602') 
      end
    end

    context 'when given a bare item ID' do
      let(:item) { HTItem.new('uc1.$b123456') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('uc1') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq('$b123456') 
      end
    end

    it 'throws an error for a garbage item URL' do
      expect { HTItem.new('wat is this garbage lol') }.to raise_error
    end
  end

  describe '#watch' do
    context 'when item has an unknown namespace' do
      it { expect { HTItem.new('foo.lakjdf').watch('HTS-9999') }.to raise_error(RuntimeError, /foo\.lakjdf:.*unknown namespace/i) }
    end

    context 'when item has a non-Google namespace' do
      it { expect { HTItem.new('loc.ark:/13960/t58d0dn7n').watch('HTS-9999') }.to raise_error(RuntimeError, /loc\.ark:\/13960\/t58d0dn7n.*google/i) }
    end

    context 'when item is blacklisted' do
      it { 
        item = HTItem.new('mdp.39015005021392')
        expect(db).to receive(:table_has_item?).with(item, 'feed_blacklist').and_return(true)
        expect { item.watch('HTS-9999') }.to raise_error(RuntimeError, /mdp\.39015005021392.*blacklist/i) 
      }
    end

    context 'when item is missing bib data' do
      it { expect { HTItem.new('mdp.39015123456789').watch('HTS-9999') }.to raise_error(RuntimeError, /mdp\.39015123456789.*bib data/i) }
    end

    context 'when item has a Google namespace, bib data, and is in GRIN' do
      let(:item) { HTItem.new('mdp.35112104589306') }

      before(:each) do
        allow(item).to receive(:table_has_item?).with('feed_watched_items').and_return(false)
        allow(item).to receive(:table_has_item?).with('feed_blacklist').and_return(false)
        allow(item).to receive(:table_has_item?).with('feed_queue').and_return(false)
        allow(item).to receive(:table_has_item?).with('feed_nonreturned').and_return(false)
        allow(item).to receive(:table_has_item?).with('rights_current').and_return(true)
        allow(item).to receive(:grin_instance).and_return('UOM')
      end

    end

  end

  describe '#queue_age' do
    context 'when the item is in queue' do
      before(:each) { allow(db).to receive(:queue_info).and_return($stuck_queue_info) }
      let(:item) { HTItem.new('mdp.35112104589306') }

      it 'knows how long it has been in the queue' do
        expect(item.queue_age).to_not be(nil)
      end
    end
  end

  describe '#to_s' do
    it 'returns namespace.objid' do
      expected = 'mdp.35112104589306'
      item = HTItem.new(expected)
      expect(item.to_s).to eq(expected)
    end
  end
end


RSpec.describe JiraTicket do
  let(:db) { instance_double("WatchedItemsDB") }
  let(:service) { JiraService.new(JIRA_URL,'foo','bar') }
  let(:ticket) { service.issue('HTS-9999') }

  before(:each) do
    HTItem.set_watchdb(db)
    allow(db).to receive(:queue_info)
    allow(db).to receive(:grin_instance).with('mdp').and_return({:grin_instance => 'UOM'})
    allow(db).to receive(:table_has_item?).and_return(false)
    allow(db).to receive(:table_has_item?).with(anything(),'feed_nonreturned').and_return(true)
  end

  context 'when ticket has state HT to reingest' do
    before(:each) { allow(ticket).to receive(:next_steps).and_return('HT to reingest') }

    context 'and an item is not on the watch list' do
      before(:each) { allow(db).to receive(:get).and_return(nil) }

      it "is added to watch list" do
        expect(db).to receive(:insert)
        ticket.process
      end
    end

    context 'and all items are on watch list' do
      before(:each) { 
        allow(db).to receive(:table_has_item?).with(anything(),'feed_watched_items').and_return(true) 
        allow(db).to receive(:get).and_return($watched_item)
      }

      context 'and all items are in the queue' do
        before(:each) { allow(db).to receive(:table_has_item?).with(anything(),'feed_queue').and_return(true) }

        context 'and all items are ready' do
          before(:each) { ticket.items.each { |item| allow(item).to receive(:zip_date).and_return(Time.new(2014,10,13,11,36,52,'-05:00')) } }

          it 'sets next steps to UM to investigate further' do
            allow(db).to receive(:queue_info).and_return($punted_queue_info)
            ticket.process
            expect(WebMock).to have_requested(:put, $jira_stub_url).with { |req| req.body =~ /UM to investigate further/ }
          end

          context 'and items were successfully ingested' do
            before(:each) { allow(db).to receive(:queue_info).and_return($ingested_queue_info) }
            it 'reports ingest date' do
              ticket.process
              expect(WebMock).to have_requested(:post, $jira_comment_url).with { |req| req.body =~ /#{$watched_item[:namespace]}.#{$watched_item[:id]}: ingested Mon Oct 13 11:36:52 2014/ }
            end

            it 'reports GRIN quality statistics' do
              ticket.process
              expect(WebMock).to have_requested(:post, $jira_comment_url).with { |req| req.body =~ /#{$watched_item[:namespace]}.#{$watched_item[:id]}: Audit: \(not audited\); Rubbish: \(not evaluated\); Material Error: 0%; Overall Error: 2%/ }
            end
          end

        end

        context 'and an item is not ready' do
          before(:each) { allow(db).to receive(:get).and_return($nonready_watched_item) }

          it 'and all items are enqueued more than a week, reports as stuck' do
            allow(db).to receive(:queue_info).and_return($stuck_queue_info)
            ticket.process
            expect(WebMock).to have_requested(:post, $jira_comment_url).with { |req| req.body =~ /#{ticket.items.first.to_s}: .*stuck.*/ }
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
          allow(db).to receive(:table_has_item?).with(anything(),'feed_queue').and_return(false) 
          allow(db).to receive(:queue_info).with(anything()).and_return(nil) 
        end

        it 'reports that the item has disappeared from the queue' do
          ticket.process
          expect(WebMock).to have_requested(:post, $jira_comment_url).with { |req| req.body =~ /not in queue/i }
        end
      end
    end


  end

end
