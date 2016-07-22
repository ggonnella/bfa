require "rgfa"
require_relative "record"
require_relative "file"

module BFA::RGFA

  module Compile

    def to_bfa(filename)
      file = File.open(filename, "w")
      file.print BFA::MAGIC_STRING
      each_line {|line| file.print(line.to_bfa_record)}
      file.close
      return nil
    end

  end

  module Parse

    def self.from_bfa(filename)
      BFA::File.new(filename).parse
    end

  end

end

class RGFA
  include BFA::RGFA::Compile
  extend BFA::RGFA::Parse
end
