class HTMLSanitizer
  # include @...@...
  LINKIFY_RE = %r{
      (?: ((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):)// | www\.\w |@([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.)
      [^\s<\u00A0'",]+
    }ix

  def self.linkify_with_mentions(str, opts = {})
    html = str.strip.gsub(/\n\n+/, "</p><p>").gsub("\n", "<br>")

    mentions = []

    doc = Nokogiri::HTML(html)
    doc.xpath("//text()").each do |node|
      skip = false
      p = node.parent
      while p
        if p.name.downcase == "a"
          skip = true
          break
        end
        p = p.respond_to?(:parent) ? p.parent : nil
      end
      if skip
        next
      end

      text = node.content
      text.gsub!(LINKIFY_RE) do |link|
        title = link.dup

        is_mention = false

        if m = link.match(/^@([^@]+)@([^@]+)/)
          link = "https://#{m[2]}/#{m[1]}"
          mentions.push({ :actor => link, :address => "#{m[1]}@#{m[2]}" })
          is_mention = true
        end

        "<a href=\"" << CGI.escapeHTML(link) << "\"" <<
          (is_mention ? " class=\"mention\"" : "") << ">" <<
          CGI.escapeHTML(title) << "</a>"
      end

      node.replace text
    end

    return self.sanitize(doc.xpath("//body").inner_html, opts), mentions
  end

  def self.sanitize(html, opts = {})
    if !opts[:target]
      opts[:target] = "_blank"
    end

    Sanitize.fragment(html,
      Sanitize::Config.merge(Sanitize::Config::RELAXED,
      :add_attributes => {
        "a" => {
          "rel" => "nofollow noreferrer",
          "target" => opts[:target],
        }
      })).gsub("\n", "")
  end
end
