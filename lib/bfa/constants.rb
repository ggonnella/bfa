module BFA::Constants

  MAGIC_STRING = "BFA\1"

  SIZEOF_TEMPLATE_CODE = "L<"

  SIZEOF_SIZE = 4

  NUMERIC_TEMPLATE_CODE = {
    :c => "c", :C => "C",
    :s => "s<", :S => "S<",
    :i => "l<", :I => "L<",
    :f => "E"
  }

  NUMERIC_SIZE = {
    :c => 1, :C => 1,
    :s => 2, :S => 2,
    :i => 4, :I => 4,
    :f => 8
  }

end
