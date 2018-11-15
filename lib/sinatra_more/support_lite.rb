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

# This is for adding specific methods that are required by sinatra_more if activesupport isn't required

require 'yaml' unless defined?(YAML)

unless String.method_defined?(:titleize) && Hash.method_defined?(:slice)
  require 'active_support/core_ext/kernel'
  require 'active_support/core_ext/array'
  require 'active_support/core_ext/hash'
  require 'active_support/core_ext/module'
  require 'active_support/core_ext/class'
  require 'active_support/deprecation'
  require 'active_support/inflector'
end

unless String.method_defined?(:blank?)
  begin
    require 'active_support/core_ext/object/blank'
  rescue LoadError
    require 'active_support/core_ext/blank'
  end
end
