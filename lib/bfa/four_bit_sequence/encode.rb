require "rgfa/byte_array"
require_relative "../four_bit_sequence"

module BFA::FourBitSequence::Encode

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

require_relative "../../core/string"
