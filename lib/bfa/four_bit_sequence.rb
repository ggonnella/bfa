module BFA::FourBitSequence

  LETTER_TO_CODE = {
    "=" => 0, "A" => 1, "C" => 2, "M" => 3,
    "G" => 4, "R" => 5, "S" => 6, "V" => 7,
    "T" => 8, "W" => 9, "Y" => 10, "H" => 11,
    "K" => 12, "D" => 13, "B" => 14, "N" => 15,
  }

  CODE_TO_LETTER = BFA::FourBitSequence::LETTER_TO_CODE.invert

  module Encode

    def to_4bits
      retval = RGFA::ByteArray.new()
      byte = nil
      each_char do |char|
        code = BFA::FourBitSequence::LETTER_TO_CODE[char.upcase]
        code ||= 15
        if byte.nil?
          byte = (code << 4)
        else
          retval << (byte + code)
          byte = nil
        end
      end
      retval << byte if !byte.nil?
      return retval
    end

  end

  module Decode

    def parse_4bits(strsize)
      retval = ""
      each do |code|
        retval << BFA::FourBitSequence::CODE_TO_LETTER[code >> 4]
        retval << BFA::FourBitSequence::CODE_TO_LETTER[code & 15]
      end
      return retval[0..strsize-1]
    end

  end

end

class String
  include BFA::FourBitSequence::Encode
end

class RGFA::ByteArray
  include BFA::FourBitSequence::Decode
end
