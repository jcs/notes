#
# tws = []
# 20.times { tws += Twitterer.first.oauth_request("/1.1/statuses/user_timeline.json?screen_name=jcs&count=200&trim_user=true&exclude_replies=false&include_rts=false&tweet_mode=extended&include_entities=1&#{tws.any?? "max_id=" + tws.map{|z| z["id_str"].to_i }.min.to_s : ""}"); puts tws.count }
# File.write("/tmp/tweets.json", tws.uniq{|z| z["id_str"] }.to_json)
#

class TwitterImport
  def self.go
    self.import_from_timeline!("tweets.json")
    nil
  end

  def self.import_from_timeline!(file)
    js = JSON.parse(File.read(file))

    user = User.first!

    Note.transaction do
      Attachment.delete_all
      Note.delete_all

      js.sort_by{|t| t["id"] }.each do |tweet|
        n = Note.where(:import_id => tweet["id_str"]).first
        if !n
          n = Note.new
          n.import_id = tweet["id_str"]
        end
        n.contact_id = user.contact.id
        n.created_at = DateTime.parse(tweet["created_at"])

        text, attachments = self.decode_tweet_entities(tweet["entities"],
          tweet["full_text"], tweet["extended_entities"])

        n.note = text.strip

        if n.note.match(/^@/)
          next
        end

        if tweet["in_reply_to_status_id_str"].to_s != ""
          begin
            rep = Note.where(:import_id =>
              tweet["in_reply_to_status_id_str"]).first!
            n.parent_note_id = rep.id
          rescue
            raise "note #{tweet["id"]} is orphaned"
          end
        end

        n.save!
        puts "#{n.id} -> #{n.import_id}"

        attachments.each do |at|
          retried = false

          begin
            a = Attachment.new
            a.note_id = n.id
            a.width = at[:width]
            a.height = at[:height]

            case at[:type]
            when :video
              a.type = "video/mp4"
              a.duration = at[:duration]
            when :image
              if at[:url].match(/\.png/)
                a.type = "image/png"
              else
                a.type = "image/jpeg"
              end
            else
              raise "what is #{a.inspect}"
            end
            a.save!

            ab = AttachmentBlob.new
            ab.attachment_id = a.id
            print "fetch #{at[:type]} #{at[:url]}... "
            ab.data = ActivityStream.sponge.get(at[:url])
            puts "#{ab.data.bytesize}"
            ab.save!
          rescue Errno::ETIMEDOUT => e
            if retried
              raise e
            end
            retried = true
            retry
          end
        end
        puts "----"
      end
    end
    true
  end

  def self.decode_tweet_entities(entities, text, extended_entities = nil)
    if !entities.any?
      return text, []
    end

    if !extended_entities
      extended_entities = []
    end

    # entities = { "urls"=>[{"url"=>".", "indices"=>[90, 113]}, ... ] }

    # store the first index position of each entity
    indices = {}
    entities.each do |type,tentities|
      if type == "media" && extended_entities.count > 0
        next
      end

      tentities.each do |ent|
        indices[ent["indices"][0]] = { type => ent }
      end
    end

    extended_entities.each do |type,tentities|
      tentities.each do |ent|
        if !indices[ent["indices"][0]]
          indices[ent["indices"][0]] = { type => [] }
        end

        indices[ent["indices"][0]][type].push ent
      end
    end

    out = ""
    append_out = ""
    skip_to = nil

    atts = []

    # break up by utf8 chars, not bytes
    text.chars.each_with_index do |char,x|
      if skip_to && x < skip_to
        next
      end

      idx = indices[x]

      if idx && !idx["urls"].blank?
        if idx["urls"]["expanded_url"].blank?
          out += "\n" + idx["urls"]["url"]
        else
          out += "\n" + idx["urls"]["expanded_url"]
        end

        skip_to = idx["urls"]["indices"][1]

      elsif idx && (idx["media"].is_a?(Array) || !idx["media"].blank?)
        if idx["media"].is_a?(Array)
          idx["media"].each do |ent|
            if !ent["indices"].is_a?(Array)
              append_out += "<pre>#{CGI.escapeHTML(ent.inspect)}</pre>"
              next
            end

            if ent["video_info"].present?
              variant = ent["video_info"]["variants"].select{|v|
                v["content_type"] == "video/mp4" }.
                sort_by{|z| z["bitrate"] }.last

              if !variant
                raise ent["video_info"].inspect
              end

              atts.push({
                :type => :video,
                :url => variant["url"],
                :width => ent["sizes"]["large"]["w"],
                :height => ent["sizes"]["large"]["h"],
                :duration => (ent["video_info"]["duration_millis"].to_f /
                  100.0).to_i,
              })
            else
              atts.push({
                :type => :image,
                :url => ent["media_url_https"] + ":large",
                :width => ent["sizes"]["large"]["w"],
                :height => ent["sizes"]["large"]["h"],
              })
            end

            skip_to = ent["indices"][1]
          end
        else
          if idx["media"]["expanded_url"].blank?
            out += "\n" + idx["media"]["url"]
          else
            out += "\n" + idx["media"]["expanded_url"]
          end

          skip_to = idx["media"]["indices"][1]
        end

      elsif idx && !idx["user_mentions"].blank?
        out += "@" + idx["user_mentions"]["screen_name"] + "@twitter.com"
        skip_to = idx["user_mentions"]["indices"][1]

      elsif idx && !idx["hashtags"].blank?
        out += "#" + idx["hashtags"]["text"]
        skip_to = idx["hashtags"]["indices"][1]

      else
        out += char
      end
    end

    out += append_out

    return out, atts
  end
end
