class Array
  def extract!
    dup.tap { delete_if &Proc.new } - self
  end
end

module SecureRandom
  # more entropy than .hex, avoids [-=] in .base64
  def self.safe(len)
    out = ""
    while out.length < len
      out += SecureRandom.base64(len * 2).split("").select{|a|
        ('A' .. 'Z').include?(a) ||
        ('a' .. 'z').include?(a) ||
        ('0' .. '9').include?(a)
      }.join
    end

    out[0, len]
  end
end

class String
  def escape
    CGI::escapeHTML(self.to_s).gsub("'", "&#039;")
  end

  def escape_entities
    self.escape.unpack("U*").collect {|s| (s > 127 ? "&##{s};" :
      s.chr) }.join("")
  end

  def word_wrap(line_width = 80, break_sequence = "\n")
    to_s.split("\n").collect!{|line|
      line.length > line_width ?
        line.gsub(/(.{1,#{line_width}})(\s+|$)/,
        "\\1#{break_sequence}").strip : line
    } * break_sequence
  end
end

class Time
  def iso8601_with_ms
    r = self.iso8601
    if m = r.match(/\A(\d+-\d+-\d+T\d+:\d+:\d+)(.+)/)
      return "#{m[1]}.000#{m[2]}"
    end
    r
  end
end
