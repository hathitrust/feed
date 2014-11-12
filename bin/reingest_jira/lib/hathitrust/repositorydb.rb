module HathiTrust

  class RepositoryDB

    def initialize(dbh)
      @dbh = dbh
    end

    def get(item)
      return table_info(item,'feed_watched_items')
    end

    def table_info(item,table)
      return @dbh.fetch("select * from #{table} where namespace = ? and id = ?",item.namespace,item.objid).first
    end

    def queue_info(item)
      return @dbh.fetch("select datediff(CURRENT_TIMESTAMP,q.update_stamp) as age, q.status, q.update_stamp from feed_queue q where q.namespace = ? and q.id = ?",item.namespace,item.objid).first
    end

    def last_error_info(item)
      return table_info(item,'feed_last_error')
    end

    def insert(item,issue_key)
      @dbh['insert into feed_watched_items (namespace, id, issue_key) values (?, ?, ?)',item.namespace,item.objid,issue_key].insert
    end

    def grin_instance(namespace)
      fetch('select grin_instance from ht_namespaces where namespace = ?',namespace).first
    end

    def table_has_item?(table,item)
      @dbh.fetch("select namespace, id from #{table} where namespace = ? and id = ?",item.namespace,item.objid) do |row|
        # had any rows? return true
        return true
      end
      return false
    end

  end

end
