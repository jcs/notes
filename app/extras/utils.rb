class Utils
  def self.random_key(len, prefix = "")
    str = prefix.dup

    while str.length < len
      while str.length < len
        chr = OpenSSL::Random.random_bytes(1)
        ord = chr.unpack('C')[0]

        #          0            9              a            z
        if (ord >= 48 && ord <= 57) || (ord >= 97 && ord <= 122)
          # avoid ambiguous characters
          next if chr == "0" || chr == "l"

          str << chr
        end
      end
    end

    return str
  end
end
