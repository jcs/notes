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

require_relative "./form_builder/abstract_form_builder"
require_relative "./form_builder/standard_form_builder"
require_relative "./form_builder/grouped_field_form_builder"

module SinatraMore
  module FormHelpers
    # Constructs a form for object using given or default form_builder
    # form_for :user, '/register' do |f| ... end
    # form_for @user, '/register', :id => 'register' do |f| ... end
    def form_for(object, url, settings={}, &block)
      builder_class = configured_form_builder_class(settings[:builder])
      form_html = capture_html(builder_class.new(self, object), &block)
      form_tag(url, settings) { form_html }
    end

    # Constructs form fields for an object using given or default form_builder
    # Used within an existing form to allow alternate objects within one form
    # fields_for @user.assignment do |assignment| ... end
    # fields_for :assignment do |assigment| ... end
    def fields_for(object, settings={}, &block)
      builder_class = configured_form_builder_class(settings[:builder])
      fields_html = capture_html(builder_class.new(self, object), &block)
      concat_content fields_html
    end

    # Constructs a form without object based on options
    # form_tag '/register' do ... end
    def form_tag(url, options={}, &block)
      options.reverse_merge!(:method => 'post', :action => url)
      if options.delete(:multipart)
        options[:enctype] = "multipart/form-data"
      end
      inner_form_html = hidden_form_method_field(options[:method]) +
        capture_html(&block)
      if options[:method].to_sym != :get
        inner_form_html = hidden_field_tag(Rack::Csrf.field,
          :value => Rack::Csrf.csrf_token(env)) + inner_form_html
      end
      concat_content content_tag('form', inner_form_html, options)
    end

    # Constructs a field_set to group fields with given options
    # field_set_tag("Office", :class => 'office-set')
    # parameters: legend_text=nil, options={}
    def field_set_tag(*args, &block)
      options = args.extract_options!
      legend_text = args[0].is_a?(String) ? args.first : nil
      legend_html = legend_text.blank? ? '' : content_tag(:legend, legend_text)
      field_set_content = legend_html + capture_html(&block)
      concat_content content_tag('fieldset', field_set_content, options)
    end

    # Constructs list html for the errors for a given object
    # error_messages_for @user
    def error_messages_for(record, options={})
      if record.blank? || record.errors.none?
        return ""
      end
      options.reverse_merge!(:header_message =>
        "The #{record.class.to_s.downcase} could not be saved!")
      error_messages = record.errors.full_messages
      error_items = error_messages.collect{|er| content_tag(:li, er) }.
        join("\n")
      error_html = content_tag(:p, options.delete(:header_message))
      error_html << content_tag(:ul, error_items, :class => 'errors-list')
      content_tag(:div, error_html, :class => 'field-errors')
    end

    # Constructs a label tag from the given options
    # label_tag :username, :class => 'long-label'
    # label_tag :username, :class => 'long-label' do ... end
    def label_tag(name, options={}, &block)
      options.reverse_merge!(:caption => "#{name.to_s.titleize}: ",
        :for => name)
      caption_text = options.delete(:caption)
      if block_given? # label with inner content
        label_content = caption_text + capture_html(&block)
        concat_content(content_tag(:label, label_content, options))
      else # regular label
        content_tag(:label, caption_text, options)
      end
    end

    # Constructs a hidden field input from the given options
    # hidden_field_tag :session_key, :value => "__secret__"
    def hidden_field_tag(name, options={})
      options.reverse_merge!(:name => name)
      input_tag(:hidden, options)
    end

    # Constructs a text field input from the given options
    # text_field_tag :username, :class => 'long'
    def text_field_tag(name, options={})
      options.reverse_merge!(:name => name)
      input_tag(:text, options)
    end

    # Constructs a text area input from the given options
    # text_area_tag :username, :class => 'long', :value => "Demo?"
    def text_area_tag(name, options={})
      options.reverse_merge!(:name => name)
      content_tag(:textarea, options.delete(:value).to_s, options)
    end

    # Constructs a password field input from the given options
    # password_field_tag :password, :class => 'long'
    def password_field_tag(name, options={})
      options.reverse_merge!(:name => name)
      input_tag(:password, options)
    end

    # Constructs a check_box from the given options
    # options = [['caption', 'value'], ['Green', 'green1'],
    #   ['Blue', 'blue1'], ['Black', "black1"]]
    # options = ['option', 'red', 'yellow' ]
    # select_tag(:favorite_color, :options => ['red', 'yellow'],
    #   :selected => 'green1')
    # select_tag(:country, :collection => @countries,
    #   :fields => [:name, :code])
    def select_tag(name, options={})
      options.reverse_merge!(:name => name)
      collection, fields = options.delete(:collection), options.delete(:fields)
      if collection
        options[:options] = options_from_collection(collection, fields)
      end
      if groups = options.delete(:groups)
        selected = options.delete(:selected)
        select_options_html = grouped_options_for_select(groups, selected)
        if options.delete(:include_blank)
          select_options_html = options_for_select([ "" ], selected) +
            select_options_html
        end
      else
        if options.delete(:include_blank)
          options[:options].unshift('')
        end
        select_options_html = options_for_select(options.delete(:options),
          options.delete(:selected))
      end
      if options[:multiple]
        options.merge!(:name => "#{options[:name]}[]")
      end
      content_tag(:select, select_options_html, options)
    end

    # Constructs a check_box from the given options
    # check_box_tag :remember_me, :value => 'Yes'
    def check_box_tag(name, options={})
      options.reverse_merge!(:name => name, :value => '1')
      input_tag(:checkbox, options)
    end

    # Constructs a radio_button from the given options
    # radio_button_tag :remember_me, :value => 'true'
    def radio_button_tag(name, options={})
      options.reverse_merge!(:name => name)
      input_tag(:radio, options)
    end

    # Constructs a file field input from the given options
    # file_field_tag :photo, :class => 'long'
    def file_field_tag(name, options={})
      options.reverse_merge!(:name => name)
      input_tag(:file, options)
    end

    # Constructs a submit button from the given options
    # submit_tag "Create", :class => 'success'
    def submit_tag(caption="Submit", options={})
      options.reverse_merge!(:value => caption)
      input_tag(:submit, options)
    end

    # Constructs a button input from the given options
    # button_tag "Cancel", :class => 'clear'
    def button_tag(caption, options = {}, &block)
      options.reverse_merge!(:value => caption)
      content_tag(:button, caption, options, &block)
    end

    # Constructs a submit button from the given options
    # submit_tag "Create", :class => 'success'
    def image_submit_tag(source, options = {})
      options.reverse_merge!(:src => image_path(source))
      input_tag(:image, options)
    end

    protected

    # Returns an array of option items for a select field based on the given
    # collection fields is an array containing the fields to display from each
    # item in the collection
    def options_from_collection(collection, fields)
      if collection.blank?
        return ''
      end
      collection.collect{|item| [ item.send(fields.first),
        item.send(fields.last) ] }
    end

    # Returns the options tags for a select based on the given option items
    def options_for_select(option_items, selected_values = [])
      if option_items.blank?
        return ''
      end
      if !selected_values.is_a?(Array)
        selected_values = [selected_values].compact
      end
      option_items.collect{|caption, value|
        value ||= caption
        selected = selected_values.find{|v|
          v.to_s.match(/^(#{value}|#{caption})$/)
        }
        content_tag(:option, caption, :value => value, :selected => !!selected)
      }.join("\n")
    end

    # Returns the options tags for a select based on the given option items
    def grouped_options_for_select(grouped_option_items, selected_values = [])
      if grouped_option_items.blank?
        return ''
      end
      if !selected_values.is_a?(Array)
        selected_values = [selected_values].compact
      end

      grouped_option_items.map{|group|
        group_caption, opts = if group.is_a?(Hash)
          [ group.keys.first, group.values ]
        else
          [ group[0], group[1 .. -1][0] ]
        end

        content_tag(:optgroup,
          opts.map{|caption,value|
            value ||= caption
            selected = selected_values.find{|v|
              v.to_s.match(/^(#{value}|#{caption})$/)
            }
            content_tag(:option, caption, :value => value,
              :selected => !!selected)
          }.join("\n"),
          :label => group_caption)
      }.join("\n")
    end

    # returns the hidden method field for 'put' and 'delete' forms
    # Only 'get' and 'post' are allowed within browsers;
    # 'put' and 'delete' are just specified using hidden fields with form
    # action still 'put'.
    # hidden_form_method_field('delete') =>
    #   <input name="_method" value="delete" />
    def hidden_form_method_field(desired_method)
      if desired_method.to_s.match(/get|post/)
        return ''
      end
      original_method = desired_method.dup
      desired_method.replace('post')
      hidden_field_tag(:_method, :value => original_method)
    end

    # Returns the FormBuilder class to use based on all available setting
    # sources
    # If explicitly defined, returns that, otherwise returns defaults
    # configured_form_builder_class(nil) => StandardFormBuilder
    def configured_form_builder_class(explicit_builder = nil)
      default_builder = if self.respond_to?(:settings) &&
      self.settings.respond_to?(:default_builder)
        self.settings.default_builder
      else
        nil
      end

      configured_builder = explicit_builder || default_builder ||
        'StandardFormBuilder'
      if configured_builder.is_a?(String)
        configured_builder = configured_builder.constantize
      end
      configured_builder
    end
  end
end
