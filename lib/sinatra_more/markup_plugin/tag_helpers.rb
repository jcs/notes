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
  module TagHelpers
    # Creates an html input field with given type and options
    # input_tag :text, :class => "test"
    def input_tag(type, options = {})
      options.reverse_merge!(:type => type)
      tag(:input, options)
    end

    # Creates an html tag with given name, content and options
    # content_tag(:p, "hello", :class => 'light')
    # content_tag(:p, :class => 'dark') do ... end
    # parameters: content_tag(name, content=nil, options={}, &block)
    def content_tag(*args, &block)
      name = args.first
      options = args.extract_options!
      tag_html = block_given? ? capture_html(&block) : args[1]
      tag_result = tag(name, options.merge(:content => tag_html))
      block_is_template?(block) ? concat_content(tag_result) : tag_result
    end

    # Creates an html tag with the given name and options
    # tag(:br, :style => 'clear:both')
    # tag(:p, :content => "hello", :class => 'large')
    def tag(name, options={})
      content = options.delete(:content)
      identity_tag_attributes.each { |attr| options[attr] = attr.to_s if options[attr]  }
      html_attrs = options.collect { |a, v| v.blank? ? nil : "#{a}=\"#{v}\"" }.compact.join(" ")
      base_tag = (!html_attrs.blank? ? "<#{name} #{html_attrs}" : "<#{name}")
      base_tag << (content ? ">#{content}</#{name}>" : " />")
    end

    def meta_tag(name, content, options = {})
      html_attrs = options.collect{|a,v|
        if v.blank?
          nil
        else
          "#{Rack::Utils.escape_html(a)}=\"#{Rack::Utils.escape_html(v)}\""
        end
      }.compact.join(" ")

      "<meta name=\"#{Rack::Utils.escape_html(name)}\" " <<
        "content=\"#{Rack::Utils.escape_html(content)}\" " <<
        (html_attrs.blank? ? "" : html_attrs << " ") << "/>"
    end

    protected

    # Returns a list of attributes which can only contain an identity value (i.e selected)
    def identity_tag_attributes
      [:checked, :disabled, :selected, :multiple]
    end
  end
end
