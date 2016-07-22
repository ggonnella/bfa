require "rgfa/cigar_operation"
require_relative "../binary_cigar"

module BFA::BinaryCigar::Decode

  def parse_binary_cigar
    RGFA::CIGAR::Operation.new(self >> 4,
                               BFA::BinaryCigar::NUM_TO_OPCODE[self & 15])
  end

end

require_relative "../../core/integer"
