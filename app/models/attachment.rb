class Attachment < DBModel
  belongs_to :note
  belongs_to :contact
  has_one :blob,
    :class_name => "AttachmentBlob",
    :dependent => :destroy

  TYPES = {
    :image => "image/jpeg",
    :jpeg => "image/jpeg",
    :png => "image/png",
    :gif => "image/gif",
    :video => "video/mp4",
  }

  MAX_SIZE = 300

  def self.build_from_upload(params)
    a = Attachment.new
    a.build_blob
    a.blob.data = params[:tempfile].read
    a.type = params[:type]
    a.infer_size!
    return a, nil
  end

  def self.build_from_url(url)
    a = Attachment.new
    a.source = url

    begin
      res = ActivityStream.fetch(uri: url, method: :head)
      if !res.ok?
        return nil, "failed querying attachment #{url}: #{res.status}"
      end
    rescue Timeout::Error, StandardError => e
      return nil, "failed querying attachment #{url}: #{e.message}"
    end

    a.type = res.headers["Content-Type"]

    if a.image?
      begin
        res = ActivityStream.fetch(uri: url, method: :get)
        if !res.ok? || res.body.to_s == ""
          return nil, "failed fetching attachment #{url}: #{res.status}"
        end
      rescue Timeout::Error, StandardError => e
        return nil, "failed querying attachment #{url}: #{e.message}"
      end

      a.build_blob
      a.blob.data = res.body
      a.infer_size!
    end

    return a, nil
  end

  def self.fetch_for_queue_entry(qe)
    at, err = Attachment.build_from_url(qe.object["url"])
    if !at
      return false, "[q#{qe.id}] [n#{qe.note_id}] failed fetching " <<
        "attachment at #{qe.object["url"].inspect}: #{err}"
    end
    at.summary = qe.object["summary"]
    at.note_id = qe.note_id
    at.save!

    App.logger.info "[q#{qe.id}] [n#{qe.note_id}] [a#{at.id}] fetched " <<
      "attachment"

    return true, nil
  end

  def activitystream_object
    {
      "type" => "Document",
      "mediaType" => self.type,
      "url" => self.media_url,
      "width" => self.width,
      "height" => self.height,
    }
  end

  def html
    if image?
      "<a href=\"#{self.media_url}\">" <<
        "<img src=\"#{self.media_url}\" loading=\"lazy\" " <<
        "intrinsicsize=\"#{self.width}x#{self.height}\"></a>"
    elsif video?
      "<video controls=1 preload=metadata " <<
        "intrinsicsize=\"#{self.width}x#{self.height}\">\n" <<
        "<source src=\"#{self.media_url}\" type=\"#{self.type}\" />\n" <<
        "Your browser doesn't seem to support HTML video. " <<
        "You can <a href=\"#{self.media_url}\">" <<
        "download the video</a> instead.\n" <<
      "</video>"
    else
      "#{self.type}?"
    end
  end

  def image?
    !!self.type.match(/\Aimage\//)
  end

  def infer_size!
    if self.image?
      begin
        reader, writer = IO.pipe("binary", :binmode => true)
        writer.set_encoding("binary")

        pid = fork do
          reader.close

          # lock down
          Pledge.pledge("stdio")

          input = GD2::Image.load(self.blob.data).to_true_color

          if input.width == 0 || input.height == 0
            raise "invalid size #{input.width}x#{input.height}"
          end

          writer.write([ input.width, input.height ].pack("LL"))

          # TODO: strip EXIF losslessly

          writer.close
          exit!(0) # skips exit handlers
        end

        writer.close

        result = "".encode("binary")
        while !reader.eof?
          result << reader.read(1024)
        end

      rescue Errno::EPIPE
        STDERR.puts "got EPIPE forking image converter"
      ensure
        begin
          reader.close
        rescue
        end
        Process.wait(pid)
      end

      #self.width, self.height, data = result.to_s.unpack("LLa*")
      self.width, self.height = result.to_s.unpack("LL")
    end

    self
  end

  def media_object
    {
      :id => self.id.to_s,
      :type => (self.video? ? "video" : "image"),
      :url => self.media_url,
      :preview_url => self.media_url,
      :remote_url => self.source,
      :meta => {
        :focus => {
          :x => 0.0,
          :y => 0.0,
        },
        :original => {
          :width => self.width.to_i,
          :height => self.height.to_i,
          :size => "#{self.width.to_i}x#{self.height.to_i}",
          :aspect => (self.height.to_i > 0 ? (self.width / self.height.to_f) :
            1.0),
        },
        :small => {
          :width => self.width.to_i,
          :height => self.height.to_i,
          :size => "#{self.width.to_i}x#{self.height.to_i}",
          :aspect => (self.height.to_i > 0 ? (self.width / self.height.to_f) :
            1.0),
        },
      },
      :description => self.summary.to_s,
      :blurhash => "",
    }
  end

  def media_url
    self.source.present? ? self.source :
      "#{App.attachment_base_url}/attachments/#{id}"
  end

  def timeline_object
    {
      "id" => self.id.to_s,
      "type" => self.video? ? "video" : "image",
      "url" => self.url,
      "preview_url" => self.media_url,
      "remote_url" => self.source,
    }
  end

  def url
    "#{App.base_url}/attachments/#{id}"
  end

  def video?
    !!self.type.match(/\Avideo\//)
  end
end
