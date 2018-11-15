require_relative "spec_helper.rb"

describe UniqueId do
  it "gives an id" do
    t = Time.now
    sleep 0.6

    oseq = UniqueId.sequence

    UniqueId.node = 5
    uid = UniqueId.get
    assert uid

    sleep 0.6
    t2 = Time.now

    uobj = UniqueId.new(uid)
    assert uobj

    assert_operator uobj.time.to_i, :>=, t.to_i
    assert_operator uobj.time.to_i, :<, t2.to_i

    assert_equal uobj.node, 5

    pid = UniqueId.truncate_pid($$)
    assert_operator pid, :>, 0
    assert_equal uobj.pid, pid

    assert_equal uobj.sequence, oseq + 1
  end

  it "parses an id" do
    u = UniqueId.parse(60449109262819330)
    assert_equal u.binary,
      "0000000011010110110000100010010100000100100110010110000000000010"
    assert_equal u.node, 0
    assert_equal u.pid, 18838
    assert_equal u.sequence, 2
  end

  it "handles big times" do
    b = UniqueId.build_binary(
      Time.parse("2040-02-03 04:05:06").to_i - UniqueId::EPOCH,
      1,
      65535,
      1234)
    u = UniqueId.new(b.to_i(2))
    assert_equal u.time.year, 2040
  end

  it "does not collide" do
    threadids = {}
    allids = {}
    threads = []

    10.times do |x|
      threads.push Thread.new {
        reader, writer = IO.pipe("binary", :binmode => true)
        writer.set_encoding("binary")

        fork do
          reader.close
          ids = (2 ** UniqueId::LENGTHS[:sequence]).times.map{ UniqueId.get }
          writer.write(ids.join(","))
          exit!(0)
        end

        writer.close

        ids = reader.read.split(",").map{|i| i.to_i }
        threadids[x] = ids
      }
    end

    threads.each{|z| z.join }

    assert_equal threadids.keys.count, 10

    threadids.each do |k,v|
      v.each_with_index do |iv,ik|
        if ik == 0
          next
        end

        assert_equal UniqueId.new(iv).time.year, Time.now.year

        if UniqueId.new(iv).time.to_i < UniqueId.new(v[ik - 1]).time.to_i
          raise "#{iv} is not >= #{v[ik - 1]}"
        end
      end

      v.each_with_index do |i,x|
        if allids[i]
          raise "collision of #{i}! (thread #{k}, index #{x})"
        else
          allids[i] = true
        end
      end
    end
  end
end
