require 'rest_client'

module HathiTrust

  GRIN_URL = "https://books.google.com/libraries" 

  class GRIN

    def initialize(instance)
      @resource = RestClient::Resource.new("#{GRIN_URL}/#{instance}/")
    end

    def item(barcode)
      return Hash[@resource['_barcode_search'].get(:params => {:format => 'text', 
                                                   :mode => 'full', 
                                                   :execute_query => 'true', 
                                                   :barcodes => barcode.upcase})
      .split("\n")
      .map { |x| x.split("\t") }
      .transpose]
    end
  end

  class GRINItem < QueueItem

    def initialize(item_url)
      super(item_url)
      grin_info
    end

    def grin_info
      namespace_info = @@db.grin_instance(namespace)

      if(namespace_info)
        grin_instance = namespace_info[:grin_instance]
        if(grin_instance)
          return GRIN.new(grin_instance).item(@objid)
        else
          raise "#{self}: reingest is only supported for Google ingest"
        end
      else
        raise "#{self}: unknown namespace #{@namespace}"
      end
    end

    def scan_date
      return DateTime.parse(grin_info['Scanned Date'])
    end

    def process_date
      return DateTime.parse(grin_info['Processed Date'])
    end

    def analyze_date
      return DateTime.parse(grin_info['Analyzed Date'])
    end

    def analyzed_since(request_date)
      return analyze_date > request_date
    end

    def convert_date
      return DateTime.parse(grin_info['Converted Date'])
    end

    # need to check whether analyze is after either convert date and zip date
    # example of when convert date is not sufficient:
    #   if item was converted but never successfully ingested
    # example of when zip date is not sufficient:
    #   if item was converted, then reanalyzed, then downloaded before the conversion expired.
    #
    def reanalyzed?
      return (analyze_date > convert_date or analyze_date > zip_date)
    end

    def reprocessed?
      return (process_date > convert_date or process_date > zip_date)
    end

    def rescanned?
      return (scan_date > convert_date or scan_date > zip_date)
    end
  end

end

