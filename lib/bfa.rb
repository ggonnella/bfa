BFA = Module.new

require_relative "bfa/constants"

# Binary format derived from GFA
module BFA
  include BFA::Constants
end

require_relative "bfa/rgfa"
