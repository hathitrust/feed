module HathiTrust
  class HTItem
    attr_reader :objid
    attr_reader :namespace

    def initialize(item_url)
      # Try to extract ID from item ID
      if item_url =~ /babel.hathitrust.org.*id=(.*)/
        item_id = $1;
      elsif item_url =~ /hdl.handle.net\/2027\/(.*)/
        item_id = $1;
      else
        item_id = item_url
      end

      if item_id =~ /(\w{0,4})\.(.*)/
        @namespace = $1
        @objid = $2
      else
        raise "Can't parse item_url"
      end
    end

    def to_s
      return "#{namespace}.#{objid}"
    end

    def zip_date
      if path = zip_path 
        return File.stat(path).mtime.to_datetime
      else 
        return nil
      end
    end

    def zip_age
      return DateTime.now - zip_date
    end

    def zip_path
      pt = Pairtree.at("/sdr1/obj/#{namespace}")
      begin
        return pt["#{namespace}.#{objid}"].to_path + "/#{objid}.zip"
      rescue Errno::ENOENT
        return nil
      end
    end

    def in_repository?
      return File.exists?(zip_path)
    end
  end

  class QueueItem < HTItem
    def self.set_watchdb(db)
      @@db = db
    end


    def in_table?(table)
      return @@db.table_has_item?(table,self)
    end

    def queued?
      return @@db.table_has_item?('feed_queue',self)
    end

    def queue_age
      return if_not_nil(@@db.queue_info(self),:age)
    end

    def queue_status
      return if_not_nil(@@db.queue_info(self),:status)
    end

    def queue_last_update
      return if_not_nil(@@db.queue_info(self),:update_stamp)
    end

    def last_error
      my_error_info = @@db.last_error_info(self)
      if my_error_info[:detail] == 'Unexpected GRIN state' and my_error_info[:message] == 'GRIN could not convert book' 
        return "conversion failure"
      else
        return "unknown"
      end
    end

    protected

    def if_not_nil(hash,sym)
      if(hash)
        return hash[sym]
      else
        return nil
      end
    end

  end
end
