module Rack
  class ExceptionMailer
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env)

    rescue => e
      email e, env

      return [
        500,
        { "Content-Type" => "text/html" },
        [ "<html><body><h1>Internal Server Error</h1><p>:(</p></body></html>" ],
      ]
    end

  private
    def email(exception, env)
      b = body(exception, env)

      if App.exception_recipients.any?
        Pony.mail(
          :to => App.exception_recipients,
          :subject => "[#{App.name}] #{exception.class} exception " <<
            "(#{exception.message[0, 50]})",
          :body => b
        )
      end

      STDERR.puts b
    end

    def first_app_call(exception)
      exception.backtrace.each do |l|
        if (rp = relative_path(l)).match(/^app\//)
          return rp
        end
      end

      relative_path(exception.backtrace[0])
    end

    def body(exception, env)
      o = [
        "#{exception.class} exception:",
        "",
        "  #{exception.message}",
        "",
        first_app_call(exception),
        "",
        "Request:",
        "-------------------------------",
        "",
        "  URL:        #{env["REQUEST_URI"]}",
        "  Method:     #{env["REQUEST_METHOD"]}",
        "  IP address: #{env["REMOTE_ADDR"]}",
        "  User agent: #{env["HTTP_USER_AGENT"]}",
        "",
        "Parameters:",
        "-------------------------------",
      ]

      App.filter_parameters(env["sinatra.error.params"] || {}).each do |k,v|
        o.push "  #{k}: #{v}"
      end

      o += [
        "",
        "Backtrace:",
        "-------------------------------",
      ]

      exception.backtrace.each do |l|
        o.push "  #{relative_path(l)}"
      end

      o.join("\n")
    end

    def relative_path(path)
      if path[0, App.root.length] == App.root
        path[App.root.length .. -1].gsub(/^\//, "")
      else
        path
      end
    end
  end
end
