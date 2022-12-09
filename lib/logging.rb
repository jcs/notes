module Sinatra
  class Request
    def current_controller
      env["sinatree_current_controller"]
    end
    def current_controller=(c)
      env["sinatree_current_controller"] = c
    end

    def log_extras
      env["sinatree_log_extras"] ||= {}
    end

    def uuid
      @uuid ||= SecureRandom.uuid
    end
  end
end

module Sinatree
  class Logger
    def initialize(app, logger = nil)
      @app = app
      @logger = logger
    end

    def call(env)
      began_at = Time.now.to_f
      request = Sinatra::Request.new(env)
      status, headers, body = @app.call(env)
      headers = Rack::Utils::HeaderHash[headers]
      headers["X-Request-Id"] = request.uuid
      body = Rack::BodyProxy.new(body) {
        log(env, request, status, headers, began_at)
      }
      [status, headers, body]
    end

  private
    # Log the request to the configured logger.
    def log(env, request, status, headers, began_at)
      logger = @logger || env[RACK_ERRORS]

      # "text/html" -> "html", "application/ld+json; profile..." -> "ld+json"
      output_format = headers["Content-Type"].to_s.split("/")[1].to_s.
        split(";")[0]

      msg = [
        "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}]",
        "[#{headers["X-Request-Id"]}]",
        "[#{env["HTTP_X_FORWARDED_FOR"] || env["REMOTE_ADDR"] || "?"}]",
        "method=#{env["REQUEST_METHOD"]}",
        "path=#{env["PATH_INFO"]}",
        "controller=#{request.current_controller}",
        "input=#{request.content_length.to_i}",
        "output=#{headers["Content-Length"]}",
        "format=#{output_format}",
        "status=#{status}",
        "duration=#{sprintf("%0.2f", Time.now.to_f - began_at)}",
      ]

      if (300..399).include?(status)
        msg << "location=#{headers["Location"]}"
      end

      msg << "params=#{App.filter_parameters(request.params).inspect}"

      request.log_extras.each do |k,v|
        msg << "#{k}=#{v}"
      end

      msg = msg.join(" ") << "\n"

      if logger.respond_to?(:write)
        logger.write(msg)
      else
        logger << msg
      end
    rescue => e
      STDERR.puts "failed writing log!: #{e.message}\n"
      STDERR.puts e.backtrace.map{|l| "  #{l}" }.join("\n")
    end
  end
end
