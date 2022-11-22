class Array
  def extract!
    dup.tap { delete_if &Proc.new } - self
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
