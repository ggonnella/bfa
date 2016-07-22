module BFA::BinaryCigar

  OPCODE_TO_NUM = {
    :"M" => 0, :"I" => 1, :"D" => 2, :"N" => 3,
    :"S" => 4, :"H" => 5, :"P" => 6, :"=" => 7,
    :"X" => 8
  }

  NUM_TO_OPCODE = OPCODE_TO_NUM.invert

end
