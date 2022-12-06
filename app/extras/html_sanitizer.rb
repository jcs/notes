class HTMLSanitizer
  # include @...@...
  LINKIFY_RE = %r{
      (?: ((?:ed2k|ftp|http|https|irc|mailto|news|gopher|nntp|telnet|webcal|xmpp|callto|feed|svn|urn|aim|rsync|tag|ssh|sftp|rtsp|afs|file):)// | www\.\w |@([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.)
      [^\s<\u00A0'",]+
    }ix

  def self.linkify(str, opts = {})
    html = str.strip.gsub(/\n\n+/, "</p><p>").gsub("\n", "<br>")

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

        if m = link.match(/^@([^@]+)@([^@]+)/)
          if m[2] == "twitter.com"
            link = "https://twitter.com/#{m[1]}"
          else
            link = "#{App.base_url}/locate/#{CGI.escape(m[1] + "@" + m[2])}"
          end
        end

        "<a href=\"" << CGI.escapeHTML(link) << "\">" <<
          CGI.escapeHTML(title) << "</a>"
      end

      node.replace text
    end

    self.sanitize(doc.xpath("//body").inner_html, opts)
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
      }))
  end
end
