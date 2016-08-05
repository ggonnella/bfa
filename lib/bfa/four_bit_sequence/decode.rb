require_relative "../four_bit_sequence"

module BFA::FourBitSequence::Decode

  def parse_4bits(strsize)
    retval = ""
    each do |code|
      retval << BFA::FourBitSequence::CODE_TO_LETTER[code >> 4]
      retval << BFA::FourBitSequence::CODE_TO_LETTER[code & 15]
    end
    return retval[0..strsize-1]
  end

end

class RGFA::ByteArray
  include BFA::FourBitSequence::Decode
end
