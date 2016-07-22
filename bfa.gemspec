Gem::Specification.new do |s|
  s.name = 'bfa'
  s.version = '1.1'
  s.date = '2016-07-22'
  s.summary = 'Write and parse the BFA format in Ruby'
  s.description = <<-EOF
    The Graphical Fragment Assembly (GFA) is a proposed format which allow
    to describe the product of sequence assembly and is implemented in the
    RGFA class defined in the rgfa gem.

    The GFA format is a text format. This gem defines a complementary binary
    format, BFA. The methods in this class allow to write a BFA file from a
    RGFA object, and to parse a BFA file into a RGFA object. This also allows
    the conversion from/to GFA format.

    This gem depends on the "rgfa" gem.
  EOF
  s.author = 'Giorgio Gonnella'
  s.email = 'gonnella@zbh.uni-hamburg.de'
  s.files = [
              'lib/bfa.rb',
              'lib/bfa/binary_cigar.rb',
              'lib/bfa/binary_cigar/decode.rb',
              'lib/bfa/binary_cigar/encode.rb',
              'lib/bfa/constants.rb',
              'lib/bfa/file.rb',
              'lib/bfa/file/format_error.rb',
              'lib/bfa/record.rb',
              'lib/bfa/error.rb',
              'lib/bfa/four_bit_sequence.rb',
              'lib/bfa/four_bit_sequence/decode.rb',
              'lib/bfa/four_bit_sequence/encode.rb',
              'lib/core/integer.rb',
              'lib/core/string.rb',
              'lib/rgfa/byte_array.rb',
              'lib/rgfa/cigar_operation.rb',
              'lib/rgfa/line.rb',
            ]
  s.homepage = 'http://github.com/ggonnella/bfa'
  s.license = 'CC-BY-SA'
  s.required_ruby_version = '>= 2.0'
end
