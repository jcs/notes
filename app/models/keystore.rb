class Keystore < DBModel
  def self.increment(key, amount = 1, expire_extension = 0)
    # atomically increment and select new value and expiration.
    # we could always do 'insert into .. on duplicate key update' but it's
    # slow, and in the majority of cases, the key will already exist

    now = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    # atomic update and fetch, unless the key is expired then we consider it
    # gone
    self.connection.execute("SET @last_inc := NULL")

    update = "UPDATE #{self.table_name} SET " <<
      "`value` = (@last_inc := COALESCE(`value`, 0) + #{q(amount)})"

    if expire_extension > 0
      update << ", expiration = DATE_ADD(IFNULL(expiration, '#{now}'), " <<
        "INTERVAL #{expire_extension.to_i} SECOND) "
    end

    update << " WHERE `key` = #{q(key)} AND " <<
      "(expiration IS NULL OR expiration > '#{now}')"

    self.connection.execute(update)
    rets = Keystore.connection.execute("SELECT CAST(@last_inc AS SIGNED)").first

    if !rets[0]
      # key didn't exist or it did but is expired, wipe it out
      self.connection.execute("DELETE FROM #{self.table_name} WHERE " <<
        "`key` = #{q(key)} AND expiration IS NOT NULL AND " <<
        "expiration <= '#{now}'")

      upsert = "UPDATE " <<
        "`value` = (@last_inc := COALESCE(`value`, 0) + #{q(amount)})"

      if expire_extension > 0
        upsert << ", expiration = DATE_ADD(IFNULL(expiration, '#{now}'), " <<
          "INTERVAL #{expire_extension.to_i} SECOND)"
      end

      # need to create row, but be mindful of a race to the insert
      self.connection.execute("SET @cur_value = NULL")

      retried = false
      begin
        self.connection.execute("INSERT INTO #{self.table_name} " <<
          "(`key`, `value`, expiration) VALUES " <<
          "(#{q(key)}, @cur_value := #{amount}, " <<
          (expire_extension > 0 ? "DATE_ADD('#{now}', INTERVAL " <<
            "#{expire_extension.to_i} SECOND)" : "NULL") <<
          ") " <<
          "ON DUPLICATE KEY " <<
          upsert)

      rescue ActiveRecord::StatementInvalid => e
        if e.message.to_s.match(/Deadlock found/) && !retried
          retried = true
          retry
        else
          raise e
        end
      end

      rets = self.connection.execute("SELECT CAST(@cur_value AS SIGNED)").first
    end

    if !rets[0]
      raise "failed incrementing key #{key}"
    end

    rets[0].to_i
  end

  def self.decrement(key, amount = 1)
    self.increment(key, amount * -1)
  end

  def self.expire(key, seconds)
    self.connection.execute("UPDATE #{self.table_name} " <<
      "SET expiration = " <<
      "'#{(Time.now + seconds).strftime("%Y-%m-%d %H:%M:%S")}' " <<
      "WHERE `key` = #{q(key)}")
  end

  def self.get(key)
    ks = self.where(:key => key).
      where("expiration IS NULL OR expiration > ?",
      Time.now.strftime("%Y-%m-%d %H:%M:%S")).first
    if ks
      return ks.value
    else
      return nil
    end
  end

  def self.put(key, value)
    self.connection.execute("INSERT INTO #{self.table_name} " +
      "(`key`, `value`) VALUES (#{q(key)}, #{q(value)}) ON DUPLICATE KEY " +
      "UPDATE `value` = #{q(value)}, expiration = NULL")
  end

  def self.del(key)
    self.where(:key => key).delete_all
  end

  # set add, stored as bracket-surrounded string (so srem can properly delete
  # values)
  def self.sadd(key, values = [])
    if !values.is_a?(Array)
      values = [ values ]
    end

    values.each do |v|
      if !v
        next
      end

      vs = "[#{v}]"

      # avoid duplicates by searching for the string first
      self.connection.execute("INSERT INTO #{self.table_name} " <<
        "(`key`, `value`) VALUES (#{q(key)}, #{q(vs)}) " <<
        "ON DUPLICATE KEY " <<
        "UPDATE `value` = " <<
        "CONCAT(`value`, IF(LOCATE(#{q(vs)}, `value`) = 0, #{q(vs)}, ''))")
    end

    true
  end

  # sadd, but not caring about duplicating already-present values (because
  # smembers will uniq them anyway)
  def self.sadd_fast(key, values = [])
    if !values.is_a?(Array)
      values = [ values ]
    end

    vs = values.select{|v| v }.uniq.map{|v| "[#{v}]" }.join("")

    self.connection.execute("INSERT INTO #{self.table_name} " <<
      "(`key`, `value`) VALUES (#{q(key)}, #{q(vs)}) " <<
      "ON DUPLICATE KEY " <<
      "UPDATE `value` = " <<
      "CONCAT(`value`, #{q(vs)})")

    true
  end

  # set unique values, stored as bracket-surrounded values
  def self.smembers(key)
    ks = self.where(:key => key).first
    if ks
      vals = ks.value.to_s.split("][")
      if vals.length == 0
        return []
      else
        # strip off [ from first one, ] from last one
        vals[0] = vals[0].gsub(/\A\[/, "")
        vals[vals.length - 1] = vals.last.gsub(/\]\z/, "")
        return vals.uniq
      end
    else
      return []
    end
  end

  # set delete, stored as bracket-surrounded string
  def self.srem(key, values = [])
    if !values.is_a?(Array)
      values = [ values ]
    end

    values.each do |v|
      vs = "[#{v}]"

      self.connection.execute("UPDATE #{self.table_name} SET " <<
        "`value` = REPLACE(`value`, #{q(vs)}, '') WHERE `key` = #{q(key)}")
    end

    true
  end

  # set set, stored as bracket-surrounded string
  def self.sset(key, values = [])
    if !values.is_a?(Array)
      values = [ values ]
    end
    values = values.map{|v| "[#{v}]" }.uniq.join("")

    self.connection.execute("INSERT INTO #{self.table_name} " <<
      "(`key`, `value`) VALUES (#{q(key)}, #{q(values)}) " <<
      "ON DUPLICATE KEY " <<
      "UPDATE `value` = #{q(values)}")

    true
  end

  # sql dates are in local time because everything uses NOW() instead of ruby
  # datetimes
  def expiration_local
    ActiveSupport::TimeZone.new("America/Chicago").
      local_to_utc(self.expiration).to_time
  rescue TZInfo::PeriodNotFound
    # *shrug*
    self.expiration.to_time
  end
end
