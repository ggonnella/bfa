require "rgfa"
require_relative "../bfa/four_bit_sequence/decode"

class RGFA::ByteArray
  include BFA::FourBitSequence::Decode
end
