require "rgfa"
require_relative "four_bit_sequence"
require_relative "binary_cigar"

class BFA::Record

  include BFA::Constants

  # @return [RGFATools::BFARecord]
  def initialize(record_type)
    # <assert> RGFA::Line::RECORD_TYPES.include?(record_type)
    @template = "x#{SIZEOF_SIZE}" # leave space for record size
    @data = []
    @temp_storage = nil
    add_fixlenstr(record_type)
  end

  # Add an optional field to the record
  def add_optfield(fieldname, value, val_type)
    val_type ||= value.gfa_datatype
    add_fixlenstr(fieldname)
    add_fixlenstr(val_type)
    add_data_item(val_type, value)
  end

  # Add a required field to the record
  def add_reqfield(value, val_type)
    add_data_item(val_type, value)
  end

  # @return [String] a binary string representation of the data;
  #   to field data is prepended as an uint32_t value which contains
  #   the size of the string in bytes (including the size value itself)
  def to_s
    bfa_str = @data.pack(@template)
    write_record_size(bfa_str)
    return bfa_str
  end

  private

  def write_record_size(bfa_str)
    STDERR.puts "@recordsize = #{bfa_str.size}"
    bfa_str_size_str = [bfa_str.size].pack(SIZEOF_TEMPLATE_CODE)
    bfa_str[0..(bfa_str_size_str.size-1)] = bfa_str_size_str
  end

  # Add a value to the record
  # @param value [Object|String] a ruby object or its rgfa datastring
  #   representation
  # @param datatype [RGFA::Line::FIELD_DATATYPE] the datatype of the data
  # @return [void]
  def add_data_item(datatype, value)
    # <assert> RGFA::Line::FIELD_DATATYPE.include?(datatype)
    case datatype
    when :A
      add_fixlenstr(value)
    when :Z
      add_cstr(value)
    when :J
      value = value.to_gfa_datastring(:J) if value.kind_of?(String)
      add_cstr(value)
    when :i
      add_int(value)
    when :f
      add_double(value)
    when :B
      add_numeric_array(value)
    when :H
      add_byte_array(value)
    when :lbl
      add_varlenstr(value)
    when :orn
      add_fixlenstr(value)
    when :seq
      add_sequence(value)
    when :pos
      add_numeric_value(:I, Integer(value))
    when :cig
      add_cigar(value)
    when :lbs
      value = value.parse_datastring(val_type) if value.kind_of?(String)
      # handled together with cgs
      @temp_storage = value
    when :cgs
      value = value.parse_datastring(val_type) if value.kind_of?(String)
      # handled together with lbs
      raise unless @temp_storage and @temp_storage.size == value.size
      add_size_of(value)
      value.size.times do |i|
        add_varlenstr(@temp_storage[i].name)
        add_fixlenstr(@temp_storage[i].orient)
        add_cigar(value[i])
      end
      @temp_storage = nil
    else
      # <assert> false # this should be impossible
    end
    return nil
  end

  def add_sequence(seq)
    # TODO: handle "*"
    add_size_of(seq)
    add_values(NUMERIC_TEMPLATE_CODE[:C], seq.to_4bits)
  end

  def add_cigar(cigar)
    # TODO: handle "*"
    cigar = cigar.cigar_operations if cigar.kind_of?(String)
    add_numeric_values(:I, cigar.map(&:to_binary))
  end

  def add_int(int)
    int = Integer(int)
    int_type = RGFA::NumericArray.integer_type(int..int)
    replace_fixlenstr(int_type)
    add_numeric_value(RGFA::NumericArray.integer_type(int..int).to_sym, int)
  end

  def add_double(float)
    add_numeric_value(:f, Float(float))
  end

  def add_numeric_array(array)
    array = array.parse_datastring(val_type) if array.kind_of?(String)
    st = array.compute_subtype
    add_fixlenstr(st)
    add_numeric_values(st.to_sym, array)
  end

  def add_byte_array(array)
    array = array.parse_datastring(val_type) if array.kind_of?(String)
    add_numeric_values(:C, array)
  end

  def add_fixlenstr(string)
    add_string(string)
  end

  def replace_fixlenstr(string)
    # <assert> @data.last.size == string.size
    @data.last.replace(string)
  end

  def add_cstr(string)
    # <assert> string.kind_of?(String) or string.kind_of?(Symbol)
    add_string(string.to_s + "\0")
  end

  def add_varlenstr(string)
    # <assert> string.kind_of?(String) or string.kind_of?(Symbol)
    add_size_of(string.to_s)
    add_string(string)
  end

  def add_string(string)
    # <assert> string.kind_of?(String) or string.kind_of?(Symbol)
    # <assert> string.size > 0
    string = string.to_s
    add_value("Z#{string.size}", string)
  end

  def add_numeric_value(val_type, number)
    # <assert> NUMERIC_TEMPLATE_CODE.has_key?(val_type)
    # <assert> number.kind_of?(Numeric)
    add_value(NUMERIC_TEMPLATE_CODE[val_type], number)
  end

  def add_numeric_values(val_type, array)
    # <assert> NUMERIC_TEMPLATE_CODE.has_key?(val_type)
    # <assert> array.kind_of?(Array)
    # <assert> array.each? {|e| e.kind_of?(Numeric)}
    add_size_of(array)
    add_values(NUMERIC_TEMPLATE_CODE[val_type], array)
  end

  def add_size_of(object)
    # <assert> object.kind_of?(Array) or object.kind_of?(String)
    add_value(SIZEOF_TEMPLATE_CODE, object.size)
  end

  def add_value(template, value)
    # <assert> value.kind_of?(String) or value.kind_of?(Numeric)
    @template << template
    @data << value
  end

  def add_values(template, array)
    # <assert> array.kind_of?(Array)
    @template += (template + array.size.to_s)
    @data += array
  end

end

class RGFA::Line

  def to_bfa_record
    bfa_record = BFA::Record.new(self.record_type)
    required_fieldnames.each do |fieldname|
      bfa_record.add_reqfield(*@data[fieldname])
    end
    optional_fieldnames.each do |fieldname|
      bfa_record.add_optfield(fieldname, *@data[fieldname])
    end
    return bfa_record
  end

end
