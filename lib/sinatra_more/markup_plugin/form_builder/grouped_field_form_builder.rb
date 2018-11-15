class GroupedFieldFormBuilder < AbstractFormBuilder
  GROUP_OPTIONS = [ :label, :hint, :help_block ].freeze

  def text_field_group(field, options={})
    options.reverse_merge!(:value => field_value(field), :id => field_id(field))
    group_wrap(field,
      @template.text_field_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def text_area_group(field, options={})
    options.reverse_merge!(:value => field_value(field), :id => field_id(field))
    group_wrap(field,
      @template.text_area_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def password_field_group(field, options={})
    options.reverse_merge!(:value => field_value(field), :id => field_id(field))
    group_wrap(field,
      @template.password_field_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def select_group(field, options={})
    options.reverse_merge!(:id => field_id(field), :selected => field_value(field))
    group_wrap(field,
      @template.select_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def check_box_group(field, options={})
    unchecked_value = options.delete(:uncheck_value) || '0'
    options.reverse_merge!(:id => field_id(field), :value => '1')
    options.merge!(:checked => true) if values_matches_field?(field, options[:value])
    html = hidden_field(field, :value => unchecked_value, :id => nil)
    html << @template.check_box_tag(field_name(field), options)

    group_wrap(field,
      html,
      options)
  end

  def radio_button_group(field, options={})
    options.reverse_merge!(:id => field_id(field, options[:value]))
    options.merge!(:checked => true) if values_matches_field?(field, options[:value])
    group_wrap(field,
      @template.radio_button_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def file_field_group(field, options={})
    options.reverse_merge!(:id => field_id(field))
    group_wrap(field,
      @template.file_field_tag(field_name(field), extract_input_options(options)),
      options)
  end

  def submit_group(caption="Submit", options={})
    group_wrap(nil,
      @template.submit_tag(caption, extract_input_options(options)),
      options.reverse_merge!(:label => ""))
  end

protected
  def field_id(field, value=nil)
    if field.blank?
      return nil
    end

    super
  end

  def group_wrap(field, content, options={})
    error_messages = field ? @object.errors[field] : nil
    group_tag = "field-group"
    if !error_messages.blank?
      group_tag << " with-errors"
    end

    html = ""

    unless options.include?(:label) && options[:label] == nil
      html << label(field, {
        :caption => (options[:label] || "#{field.to_s.titleize}:")
      })
    end

    html << content
    html << inline_help_tag(error_messages.presence || options[:hint])
    html << help_block_tag(options[:help_block])

    @template.content_tag(:div, html, :class => group_tag)
  end

  def inline_help_tag(messages)
    messages = Array.wrap(messages)
    if messages.empty?
      return ""
    end
    message_span = ActiveSupport::SafeBuffer.new(" #{messages.to_sentence}")
    @template.content_tag(:span, message_span, :class => "help-inline")
  end

  def help_block_tag(help)
    if help.blank?
      return ""
    end

    @template.content_tag(:div, help, :class => "help-block")
  end

  def extract_input_options(options)
    options.except(*GROUP_OPTIONS)
  end
end
