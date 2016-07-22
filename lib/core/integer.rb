require_relative "../bfa/binary_cigar/decode"
class Integer
  include BFA::BinaryCigar::Decode
end
