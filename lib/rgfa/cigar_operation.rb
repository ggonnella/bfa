require "rgfa"
require "rgfa/cigar_operation"
require_relative "../bfa/binary_cigar/encode"
class RGFA::CIGAR::Operation
  include BFA::BinaryCigar::Encode
end
