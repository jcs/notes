#
# Copyright (c) 2019 joshua stein <jcs@jcs.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

class UniqueId
  #
  # (roughly) time-sortable, incrementing ids that don't require an
  # auto_increment database table and will not collide between processes and
  # servers
  #
  # uses 64 bits, the size of a bigint in mysql
  #
  # [0, 32] = (time.to_f - EPOCH) * 10
  # [32, 4] = node id, 0 to 15
  # [36, 16] = pid
  # [52, 12] = sequence, 0 to 4095
  #
  # this gives us 4096 ids per second, per pid, per node/server
  # sequences are shared among threads in a process
  #

  # jan 1, 2019 00:00:00 +0000
  EPOCH = 1546300800

  LENGTHS = {
    :time => 32,
    :node => 4,
    :pid => 16,
    :sequence => 12,
  }.freeze

  attr_reader :binary, :time, :node, :pid, :sequence

  def self.build_binary(time, node, pid, seq)
    r = sprintf("%0#{LENGTHS[:time]}b%0#{LENGTHS[:node]}b" <<
      "%0#{LENGTHS[:pid]}b%0#{LENGTHS[:sequence]}b", time, node, pid, seq)

    if r.length != 64
      raise "created invalid length binary #{r.inspect} (#{r.length})"
    end

    r
  end

  def self.get
    self.get_binary.to_i(2)
  end

  def self.get_binary
    self.build_binary((Time.now.to_i - EPOCH), self.node,
      self.truncate_pid($$), self.sequence)
  end

  def self.node
    class_variable_defined?("@@node") ? @@node : 0
  end
  def self.node=(what)
    @@node = what.to_i
  end

  def self.sequence
    ret = 0

    (@@sequence_mutex ||= Mutex.new).synchronize do
      @@sequence ||= 0

      if @@sequence >= (2 ** LENGTHS[:sequence]) - 1
        ret = @@sequence = 0
      else
        ret = (@@sequence += 1)
      end
    end

    ret
  end

  def self.parse(i)
    UniqueId.new(i)
  end

  def self.truncate_pid(pid)
    # pid is technically 17 bits on openbsd, capped at 99999, so cap at 16 bits
    pid = pid.to_s(2)
    if pid.length > LENGTHS[:pid]
      pid = pid[pid.length - LENGTHS[:pid], LENGTHS[:pid]]
    end
    pid.to_i(2)
  end

  def initialize(i)
    if !i || i > (2 ** 64) - 1 || i < 0
      raise "invalid id #{i}"
    end

    @binary = sprintf("%064b", i)

    @time = Time.at(EPOCH + @binary[0, LENGTHS[:time]].to_i(2))
    z = LENGTHS[:time]

    @node = @binary[z, LENGTHS[:node]].to_i(2)
    z += LENGTHS[:node]

    @pid = @binary[z, LENGTHS[:pid]].to_i(2)
    z += LENGTHS[:pid]

    @sequence = @binary[z, LENGTHS[:sequence]].to_i(2)
  end

  def to_i
    @binary.to_i(2)
  end
end
