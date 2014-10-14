require_relative '../reingest_jira'
require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)

$jira_url = "https://wush.net/jira/hathitrust/rest/api/2/"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  config.before(:each) do
    stub_request(:get, 'https://foo:bar@wush.net/jira/hathitrust/rest/api/2/issue/HTS-9999').
      to_return(status: 200, body: File.new('hts-9999.json'), headers: {})
  end

end

RSpec.describe HTItem do
  before(:each) do
    db = instance_double("WatchedItemsDB")
    allow(db).to receive(:get)
    allow(db).to receive(:grin_instance).with('mdp').and_return({:grin_instance => 'UOM'})
    allow(db).to receive(:grin_instance).with('uc1').and_return({:grin_instance => 'UCAL'})
    allow(db).to receive(:grin_instance).with('yale').and_return({:grin_instance => nil})
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
      let(:item) { HTItem.new('yale.39002014043690') }

      it 'parses the namespace' do
        expect(item.namespace).to eq('yale') 
      end
      it 'parses the objid' do
        expect(item.objid).to eq('39002014043690') 
      end
    end

    it 'throws an error for a garbage item URL' do
      expect { HTItem.new('wat is this garbage lol') }.to raise_error
    end
  end

  describe '#watch' do
    context 'when item has an unknown namespace' do
      it { expect { HTItem.new('foo.lakjdf').watch }.to raise_error(RuntimeError, /unknown namespace/i) }
    end

    context 'when item has a non-Google namespace' do
      it { expect { HTItem.new('loc.ark:/13960/t58d0dn7n').watch }.to raise_error(RuntimeError, /google/i) }
    end

    context 'when item is blacklisted' do
      it { expect { HTItem.new('mdp.39015005021392').watch }.to raise_error(RuntimeError, /blacklist/i) }
    end

    context 'when item is missing bib data' do
      it { expect { HTItem.new('mdp.39015123456789').watch }.to raise_error(RuntimeError, /bib data/i) }
    end

    context 'when item has a Google namespace, bib data, and is in GRIN' do
      let(:item) { HTItem.new('mdp.35112104589306',ticket) }

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
end

RSpec.describe JiraTicket do
  context 'when ticket has state HT to reingest' do
    let(:service) { JiraService.new($jira_url,'foo','bar') }
    let(:ticket) { service.issue('HTS-9999') }
    let(:item) { ticket.items.first }

    it "and is not already watched, is added to watch list" do
      allow(item).to receive(:table_has_item?).with('feed_watched_items').and_return(false)
      expect(item).to receive(:watched_items_insert)
      ticket.process
    end

    context 'and is already watched' do
      before(:each) { allow(item).to receive(:table_has_item?).with('feed_watched_items').and_return(true) }

      context 'and is in the queue' do
        before(:each) { allow(item).to receive(:table_has_item?).with('feed_queue').and_return(true) }

        context 'and an item is not ready' do
          before(:each) { allow(item).to receive(:ready).and_return(false) }

          it 'and all items are enqueued more than a week, reports as stuck' do
            ticket.items.each { |item| allow(item).to receive(:queue_age).and_return(7*86400 + 1) }
            expect { ticket.process }.to raise_error(RuntimeError, /stuck/)
          end

          it 'and enqueued less than a week, returns no next step' do
            ticket.items.each { |item| allow(item).to receive(:queue_age).and_return(0) }
            expect { ticket.not_to receive(:set_next_steps) }
          end

        end

        it 'and all items are ready, sets next steps to UM to investigate further' do
          ticket.items.each { |item| allow(item).to receive(:ready).and_return(true) }
          expect { ticket.to receive(:set_next_steps).with('UM to investigate further') }
        end

      end

      context 'and is not in the queue' do
        before(:each) { ticket.items.each { |item| allow(item).to receive(:table_has_item?).with('feed_queue').and_return(false) } }

        it { expect { item.progress }.to raise_error(RuntimeError, /disappeared from queue/)  }
      end
    end


  end

end
