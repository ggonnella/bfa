module BFA::FourBitSequence

  LETTER_TO_CODE = {
    "=" => 0, "A" => 1, "C" => 2, "M" => 3,
    "G" => 4, "R" => 5, "S" => 6, "V" => 7,
    "T" => 8, "W" => 9, "Y" => 10, "H" => 11,
    "K" => 12, "D" => 13, "B" => 14, "N" => 15,
  }

  CODE_TO_LETTER = LETTER_TO_CODE.invert

end
