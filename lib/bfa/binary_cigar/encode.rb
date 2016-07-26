require_relative "../binary_cigar"

module BFA::BinaryCigar::Encode

    def to_binary
      (len << 4) |
        BFA::BinaryCigar::OPCODE_TO_NUM[code]
    end

end

require_relative "../../rgfa/cigar_operation"
