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
  end

end

