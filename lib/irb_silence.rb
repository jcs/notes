require "irb/ext/save-history"

module IRB
  module HistorySavingAbility
    alias_method :old_save_history, :save_history

    def save_history
      old_save_history

    rescue Errno::ENOENT
      # ignore write failure, we may be running as an unprivileged user
    end
  end
end
