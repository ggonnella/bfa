require "rgfa"
require_relative "error"

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
    STDERR.puts("no record anymore") if str.nil?
    return false if str.nil?
    if str.size < SIZEOF_SIZE
      raise BFA::File::FormatError
    end
    @recordbytes = str.unpack(SIZEOF_TEMPLATE_CODE)[0] - SIZEOF_SIZE
    STDERR.puts("record, bytes = #@recordbytes")
    return true
  end

  def parse_record
    record_type = read(1)
    @recordbytes -= 1
    line_data = {}
    line_klass = RGFA::Line.subclass(record_type)
    line_klass::REQFIELDS.each do |fieldname|
      parse_reqfield(line_data, fieldname, line_klass)
    end
    parse_optfield(line_data) while @recordbytes > 0
    line = line_klass.new(line_data)
    STDERR.puts line.inspect
    return line
  end

  def parse_reqfield(line_data, fieldname, line_klass)
    datatype = line_klass::DATATYPE[fieldname]
    value = parse_data_item(datatype.to_sym)
    line_data[fieldname] = [value, datatype]
  end

  def parse_optfield(line_data)
    fieldname = parse_fixlenstr(2)
    datatype = parse_fixlenstr(1)
    value = parse_data_item(datatype.to_sym)
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
      parse_numeric_value(:I)
    when :cig
      parse_cigar
    when :lbs
      # also reads cgs
      parse_path_elements
    when :cgs
      fetch_stored_cigars
    else
      # <assert> false # this should be impossible
    end
  end

  def parse_path_elements
    n_elements = parse_size
    retval = []
    raise unless @temp_storage.nil?
    @temp_storage = []
    n_elements.times do |i|
      retval << [parse_varlenstr.to_sym,
                 parse_fixlenstr(1).to_sym].to_oriented_segment
      @temp_storage << parse_cigar
    end
    return retval
  end

  def fetch_stored_cigars
    raise if @temp_storage.nil?
    retval = @temp_storage
    @temp_storage = nil
  end

  def parse_sequence
    # TODO: handle "*"
    seqsize = parse_size
    n_values = (seqsize.to_f/2).ceil
    parse_values(NUMERIC_SIZE[:C], NUMERIC_TEMPLATE_CODE[:C],
                 n_values).to_byte_array.parse_4bits(seqsize)
  end

  def parse_cigar
    parse_numeric_values(:I).map(&:parse_binary_cigar)
  end

  def parse_numeric_array
    st = parse_fixlenstr(1)
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
    parse_values(NUMERIC_SIZE[val_type],
                 NUMERIC_TEMPLATE_CODE[val_type], asize)
  end

  def parse_varlenstr
    strsize = parse_size
    parse_fixlenstr(strsize)
  end

  def parse_size
    s = parse_value(SIZEOF_SIZE, SIZEOF_TEMPLATE_CODE)
    if s <= 0
      raise BFA::File::FormatError
    end
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
        @recordbytes -= str.size
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
    if str.nil? or str.size < val_size
      raise BFA::File::FormatError
    end
    return str
  end

end

# Format error during parsing of BFA files
class BFA::File::FormatError < Error; end
