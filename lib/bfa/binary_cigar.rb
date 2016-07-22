module BFA::BinaryCigar

  OPCODE_TO_NUM = {
    "M" => 0, "I" => 1, "D" => 2, "N" => 3,
    "S" => 4, "H" => 5, "P" => 6, "=" => 7,
    "X" => 8
  }

  NUM_TO_OPCODE = OPCODE_TO_NUM.inverse

  module Encode

    def to_binary
      (oplen << 4) |
        BFA::BinaryCigar::OPCODE_TO_NUM[opcode]
    end

  end

  module Decode

    def parse_binary_cigar
      RGFA::CigarOperation.new([self >> 4,
        BFA::BinaryCigar::NUM_TO_OPCODE[self & 15]])
    end

  end

end

class RGFA::CigarOperation
  include BFA::BinaryCigar::Encode
end

class Integer
  include BFA::BinaryCigar::Decode
end
