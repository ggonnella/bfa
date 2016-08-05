require_relative "../binary_cigar"

module BFA::BinaryCigar::Encode

    def to_binary
      (len << 4) |
        BFA::BinaryCigar::OPCODE_TO_NUM[code]
    end

end

class RGFA::CIGAR::Operation
  include BFA::BinaryCigar::Encode
end
