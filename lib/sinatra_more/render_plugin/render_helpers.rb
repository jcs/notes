#
# sinatra_more
# Copyright (c) 2009 Nathan Esquenazi
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

module SinatraMore
  module RenderHelpers
    # Renders a erb template based on the relative path
    # erb_template 'users/new'
    def erb_template(template_path, options={})
      render_template template_path, options.merge(:template_engine => :erb)
    end

    # Renders a haml template based on the relative path
    # haml_template 'users/new'
    def haml_template(template_path, options={})
      render_template template_path, options.merge(:template_engine => :haml)
    end

    # Renders a template from a file path automatically determining rendering engine
    # render_template 'users/new'
    # options = { :template_engine => 'haml' }
    def render_template(template_path, options={})
      template_engine = options.delete(:template_engine) || resolve_template_engine(template_path)
      render template_engine.to_sym, template_path.to_sym, options
    end

    # Partials implementation which includes collections support
    # partial 'photo/_item', :object => @photo
    # partial 'photo/_item', :collection => @photos
    def partial(template, options={})
      options.reverse_merge!(:locals => {}, :layout => false)
      path = template.to_s.split(File::SEPARATOR)
      object_name = path[-1].to_sym
      path[-1] = "_#{path[-1]}"
      template_path = File.join(path)
      raise 'Partial collection specified but is nil' if options.has_key?(:collection) && options[:collection].nil?
      if collection = options.delete(:collection)
        options.delete(:object)
        counter = 0
        collection.collect do |member|
          counter += 1
          options[:locals].merge!(object_name => member, "#{object_name}_counter".to_sym => counter)
          render_template(template_path, options.merge(:layout => false))
        end.join("\n")
      else
        if member = options.delete(:object)
          options[:locals].merge!(object_name => member)
        end
        render_template(template_path, options.merge(:layout => false))
      end
    end
    alias render_partial partial

    private

      # Returns the template engine (i.e haml) to use for a given template_path
      # resolve_template_engine('users/new') => :haml
      def resolve_template_engine(template_path)
        resolved_template_path = File.join(self.settings.views, template_path.to_s + ".*")
        template_file = Dir[resolved_template_path].first
        raise "Template path '#{template_path}' could not be located in views!" unless template_file
        template_engine = File.extname(template_file)[1..-1].to_sym
      end
  end
end
