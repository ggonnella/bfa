BFA = Module.new

require "rgfa"

require_relative "bfa/constants"
require_relative "bfa/reader"
require_relative "bfa/writer"

class RGFA

  def to_bfa(filename, compressed=true)
    BFA::Writer.encode(filename, self, compressed)
    return nil
  end

  class << self

    alias_method :from_gfa, :from_file

    def from_file(filename)
      f = File.open(filename)
      is_gzip = (f.read(2).bytes == [31,139])
      if is_gzip
        # currently only gzipped bfa are supported
        f.close
        from_bfa(filename)
      end
      is_bfa = (f.read(4) == BFA::Constants::MAGIC_STRING)
      f.close
      if is_bfa
        from_bfa(filename)
      else
        from_gfa(filename)
      end
    end

    def from_bfa(filename)
      BFA::Reader.parse(filename)
    end

  end

end

class RGFA::Line
  attr_accessor :line_id
end
