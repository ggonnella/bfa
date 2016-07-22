BFA = Module.new

require "rgfa"

require_relative "bfa/constants"
require_relative "bfa/file"
require_relative "rgfa/line"

class RGFA

  def to_bfa(filename)
    file = File.open(filename, "w")
    file.print BFA::Constants::MAGIC_STRING
    each_line {|line| file.print(line.to_bfa_record)}
    file.close
    return nil
  end

  class << self

    alias_method :from_gfa, :from_file

    def from_file(filename)
      f = File.open(filename)
      is_bfa = (f.read(4) == BFA::Constants::MAGIC_STRING)
      f.close
      if is_bfa
        from_bfa(filename)
      else
        from_gfa(filename)
      end
    end

    def from_bfa(filename)
      BFA::File.new(filename).parse
    end

  end

end

require_relative "rgfa/cigar_operation"
require_relative "rgfa/byte_array"
require_relative "core/integer"
require_relative "core/string"
