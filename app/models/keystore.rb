class Keystore < DBModel
  def self.q(str)
    ActiveRecord::Base.connection.quote(str)
  end

  def self.increment(key, amount = 1, expire_extension = 0)
    # atomically increment and select new value and expiration.
    # we could always do 'insert into .. on duplicate key update' but it's
    # slow, and in the majority of cases, the key will already exist

    now = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    if Keystore.connection.adapter_name == "SQLite"
      Keystore.connection.execute("DELETE FROM #{self.table_name} WHERE " <<
        "`key` = #{q(key)} AND expiration <= '#{now}'")
      Keystore.connection.execute("INSERT OR IGNORE INTO " <<
        "#{self.table_name} (`key`, `value`) VALUES (#{q(key)}, 0)")
      Keystore.connection.execute("UPDATE #{self.table_name} " <<
        "SET `value` = `value` + #{q(amount)} WHERE `key` = #{q(key)}")

      if expire_extension > 0
        Keystore.connection.execute("UPDATE #{self.table_name} SET " <<
          "expiration = DATETIME(IFNULL(expiration, '#{now}'), " <<
          "'+#{expire_extension.to_i} second') WHERE `key` = #{q(key)}")
      end

      return Keystore.where(:key => key).first.try(:value).to_i
    end

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
    if Keystore.connection.adapter_name == "SQLite"
      self.connection.execute("INSERT OR REPLACE INTO #{self.table_name} " +
        "(`key`, `value`, `expiration`) VALUES (#{q(key)}, #{q(value)}, NULL)")
    else
      self.connection.execute("INSERT INTO #{self.table_name} " +
        "(`key`, `value`) VALUES (#{q(key)}, #{q(value)}) ON DUPLICATE KEY " +
        "UPDATE `value` = #{q(value)}, expiration = NULL")
    end
  end

  def self.del(key)
    self.where(:key => key).delete_all
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
