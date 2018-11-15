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

class StandardFormBuilder < AbstractFormBuilder

  # text_field_block(:username, { :class => 'long' }, { :class => 'wide-label' })
  # text_area_block(:summary, { :class => 'long' }, { :class => 'wide-label' })
  # password_field_block(:password, { :class => 'long' }, { :class => 'wide-label' })
  # file_field_block(:photo, { :class => 'long' }, { :class => 'wide-label' })
  # check_box_block(:remember_me, { :class => 'long' }, { :class => 'wide-label' })
  # select_block(:color, :options => ['green', 'black'])
  (self.field_types - [ :hidden_field, :radio_button ]).each do |field_type|
    class_eval <<-EOF
    def #{field_type}_block(field, options={}, label_options={})
      label_options.reverse_merge!(:caption => options.delete(:caption)) if options[:caption]
      field_html = label(field, label_options)
      field_html << #{field_type}(field, options)
      @template.content_tag(:p, field_html)
    end
    EOF
  end

  # submit_block("Update")
  def submit_block(caption, options={})
    submit_html = self.submit(caption, options)
    @template.content_tag(:p, submit_html)
  end

  # image_submit_block("submit.png")
  def image_submit_block(source, options={})
    submit_html = self.image_submit(source, options)
    @template.content_tag(:p, submit_html)
  end
end
