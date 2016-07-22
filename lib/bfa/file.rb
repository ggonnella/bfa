require "rgfa"
require_relative "constants"
require_relative "binary_cigar/decode"
require_relative "four_bit_sequence/decode"

class BFA::File < File

  include BFA::Constants

  # No mode parameter, as this is a read-only file class.
  # See BFARecord to write BFA files.
  def initialize(filename)
    @temp_storage = nil
    super
  end

  # @return [RGFA]
  def parse
    rgfa = RGFA.new
    validate_magic_string!
    (rgfa << parse_record) while (has_record?)
    return rgfa
  end

  private

  def validate_magic_string!
    ms = read(MAGIC_STRING.size)
    unless ms == MAGIC_STRING
      raise BFA::File::FormatError,
        "Magic string not recognized (#{ms.inspect})"
    end
  end

  def has_record?
    str = read(SIZEOF_SIZE)
    # <debug> "no record anymore" if str.nil?
    return false if str.nil?
    if str.size < SIZEOF_SIZE
      raise BFA::File::FormatError
    end
    @recordbytes = str.unpack(SIZEOF_TEMPLATE_CODE)[0] - SIZEOF_SIZE
    # <debug> "record, bytes = #@recordbytes"
    return true
  end

  def parse_record
    record_type = read(1)
    @recordbytes -= 1
    # <debug> "record type = #{record_type}"
    # <debug> "remaining bytes = #@recordbytes"
    line_data = {}
    line_klass = RGFA::Line.subclass(record_type)
    line_klass::REQFIELDS.each do |fieldname|
      parse_reqfield(line_data, fieldname, line_klass)
    end
    parse_optfield(line_data) while @recordbytes > 0
    line = line_klass.new(line_data)
    # <debug> "RGFA::Line object: #{line.inspect}"
    # <debug> "GFA line: #{line.to_s}"
    return line
  end

  def parse_reqfield(line_data, fieldname, line_klass)
    datatype = line_klass::DATATYPE[fieldname]
    # <debug> "required field fieldname: #{fieldname}"
    # <debug> "required field datatype: #{datatype}"
    value = parse_data_item(datatype.to_sym)
    # <debug> "required field value: #{value.inspect}"
    line_data[fieldname] = [value, datatype]
  end

  def parse_optfield(line_data)
    fieldname = parse_fixlenstr(2).to_sym
    # <debug> "optfield fieldname: #{fieldname}"
    datatype = parse_fixlenstr(1).to_sym
    # <debug> "optfield datatype: #{datatype}"
    value = parse_data_item(datatype.to_sym)
    # <debug> "optfield value: #{value.inspect}"
    datatype = :i if INTEGER_DATATYPES.include?(datatype)
    line_data[fieldname] = [value, datatype]
  end

  def parse_data_item(datatype)
    # <assert> datatype.kind_of?(Symbol)
    case datatype
    when :A
      parse_fixlenstr(1)
    when :Z
      parse_cstr
    when :J
      parse_cstr
    when :i, :I, :c, :C, :s, :S, :f
      parse_numeric_value(datatype)
    when :B
      parse_numeric_array
    when :H
      parse_byte_array
    when :lbl
      parse_varlenstr
    when :orn
      parse_fixlenstr(1)
    when :seq
      parse_sequence
    when :pos
      parse_position
    when :cig
      parse_cigar
    when :lbs
      # also reads cgs
      segments, cigars = parse_path_elements
      # <assert> @temp_storage.nil?
      @temp_storage = cigars
      return segments
    when :cgs
      # <assert> !@temp_storage.nil?
      cigars = @temp_storage
      @temp_storage = nil
      return cigars
    else
      # <assert> false # this should be impossible
    end
  end

  def parse_position
    parse_numeric_value(:I)
  end

  def parse_path_elements
    n_elements = parse_size
    # <debug> "path has #{n_elements} elements"
    segments = []
    cigars = []
    n_elements.times do |i|
      segments << [parse_varlenstr.to_sym,
                 parse_fixlenstr(1).to_sym].to_oriented_segment
      cigars << parse_cigar
    end
    return segments, cigars
  end

  def parse_sequence
    seqsize = parse_size
    if seqsize == 0
      return "*"
    else
      n_values = (seqsize.to_f/2).ceil
      parse_values(NUMERIC_SIZE[:C], NUMERIC_TEMPLATE_CODE[:C],
                   n_values).to_byte_array.parse_4bits(seqsize)
    end
  end

  def parse_cigar
    cigar = parse_numeric_values(:I)
    if cigar.empty?
      return "*"
    else
      return cigar.map(&:parse_binary_cigar)
    end
  end

  def parse_numeric_array
    st = parse_fixlenstr(1).to_sym
    parse_numeric_values(st).to_numeric_array
  end

  def parse_byte_array
    parse_numeric_values(:C).to_byte_array
  end

  def parse_numeric_value(val_type)
    # <assert> NUMERIC_SIZE.has_key?(val_type)
    # <assert> NUMERIC_TEMPLATE_CODE.has_key?(val_type)
    parse_value(NUMERIC_SIZE[val_type],
                NUMERIC_TEMPLATE_CODE[val_type])
  end

  def parse_numeric_values(val_type)
    # <assert> NUMERIC_SIZE.has_key?(val_type)
    # <assert> NUMERIC_TEMPLATE_CODE.has_key?(val_type)
    asize = parse_size
    if asize == 0
      return []
    else
      parse_values(NUMERIC_SIZE[val_type],
                   NUMERIC_TEMPLATE_CODE[val_type], asize)
    end
  end

  def parse_varlenstr
    strsize = parse_size
    parse_fixlenstr(strsize)
  end

  def parse_size
    s = parse_value(SIZEOF_SIZE, SIZEOF_TEMPLATE_CODE)
    return s
  end

  def parse_fixlenstr(len)
    read!(len)
  end

  def parse_cstr
    str = ""
    loop do
      c = getc
      if c.nil?
        raise BFA::File::FormatError
      elsif c == "\0"
        @recordbytes -= (str.size+1)
        # <debug> "0-term string parsed: #{str.inspect}"
        # <debug> "remaining bytes = #@recordbytes"
        return str
      else
        str << c
      end
    end
  end

  def parse_value(val_size, val_template_code)
    read!(val_size).unpack(val_template_code)[0]
  end

  def parse_values(val_size, val_template_code, numfields)
    read!(val_size*numfields).unpack(val_template_code+numfields.to_s)
  end

  def read!(val_size)
    str = read(val_size)
    @recordbytes -= val_size
    # <debug> "value read, size: #{val_size}"
    # <debug> "remaining bytes = #@recordbytes"
    if str.nil? or str.size < val_size
      raise BFA::File::FormatError
    end
    return str
  end

end

require_relative "file/format_error"
