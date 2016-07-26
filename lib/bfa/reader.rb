require "rgfa"
require "zlib"
require_relative "constants"
require_relative "binary_cigar/decode"
require_relative "four_bit_sequence/decode"

class BFA::Reader

  include BFA::Constants

  # @see BFA::Writer to write BFA files.
  def initialize(filename)
    file = File.new(filename)
    magic = file.read(2)
    file.rewind
    if magic.bytes == [31, 139]
      @io = Zlib::GzipReader.new(file)
    else
      @io = file
    end
  end

  def close
    @io.close
  end

  # @return [RGFA]
  def parse
    rgfa = RGFA.new
    validate_magic_string!
    parse_headers(rgfa)
    parse_segments(rgfa)
    parse_links(rgfa)
    parse_containments(rgfa)
    parse_paths(rgfa)
    return rgfa
  end

  def self.parse(filename)
    br = self.new(filename)
    rgfa = br.parse
    br.close
    return rgfa
  end

  private

  def validate_magic_string!
    ms = @io.read(MAGIC_STRING.size)
    unless ms == MAGIC_STRING
      raise BFA::Reader::FormatError,
        "Magic string not recognized (#{ms.inspect})"
    end
  end

  def parse_headers(rgfa)
    n_optfields = parse_size
    headers_data = {:multiple_values => []}
    n_optfields.times do
      n, t, v = parse_optfield
      if headers_data.has_key?(n)
        if :multiple_values.has_key?(n)
          headers_data[n] << v
        else
          headers_data[:multiple_values] << n
          headers_data[n] = [headers_data[n], v]
        end
      else
        headers_data[n] = v
      end
    end
    # <debug> "Headers data: #{headers_data}"
    rgfa.set_headers(headers_data)
  end

  def parse_segments(rgfa)
    n_segments = parse_size
    # <debug> "N.segments: #{n_segments}"
    n_segments.times do
      parse_segment(rgfa)
    end
  end

  def parse_optfields(line_data)
    n_optfields = parse_size
    # <debug> "N.optfields: #{n_optfields}"
    n_optfields.times do
      n, t, v = parse_optfield
      line_data[n] = [v, t]
    end
  end

  def parse_segment(rgfa)
    line_data = {}
    line_data[:name] = [parse_varlenstr.to_sym, :lbl]
    line_data[:sequence] = [parse_sequence, :seq]
    parse_optfields(line_data)
    # <debug> "Segment data: #{line_data}"
    segment = RGFA::Line::Segment.new(line_data)
    rgfa << segment
  end

  def parse_links(rgfa)
    n_links = parse_size
    # <debug> "N.links: #{n_links}"
    n_links.times do
      parse_edge(rgfa)
    end
  end

  def parse_containments(rgfa)
    n_containments = parse_size
    # <debug> "N.containments: #{n_containments}"
    n_containments.times do
      parse_edge(rgfa, true)
    end
  end

  def parse_edge(rgfa, containment=false)
    line_data = {}
    [:from, :to].each do |dir|
      line_id = parse_numeric_value(:i)
      line_data[:"#{dir}_orient"] = [line_id > 0 ? :+ : :-, :orn]
      line_data[dir] = [rgfa.segment_names[(line_id.abs)-1].to_sym, :lbl]
    end
    line_data[:overlap] = [parse_cigar, :cig]
    if containment
      line_data[:pos] = [parse_numeric_value(:I), :pos]
    end
    parse_optfields(line_data)
    # <debug> "Edge data: #{line_data}"
    edge = containment ?
             RGFA::Line::Containment.new(line_data) :
             RGFA::Line::Link.new(line_data)
    rgfa << edge
  end

  def parse_paths(rgfa)
    n_paths = parse_size
    # <debug> "N.paths: #{n_paths}"
    n_paths.times do
      parse_path(rgfa)
    end
  end

  def parse_path(rgfa)
    line_data = {}
    line_data[:path_name] = [parse_varlenstr.to_sym, :lbl]
    n_links = parse_size
    circular = false
    if n_links < 0
      n_links = -n_links
      circular = true
    end
    line_data[:segment_names] = [[], :lbs]
    line_data[:cigars] = [[], :cgs]
    n_links.times do |i|
      line_id = parse_numeric_value(:i)
      reverse_link = line_id < 0
      link = rgfa.links[line_id.abs-1]
      link = link.reverse if reverse_link
      if line_data[:segment_names][0].empty?
        line_data[:segment_names][0] <<
          [link.from, link.from_orient].to_oriented_segment
      end
      if !circular or i < (n_links-1)
        line_data[:segment_names][0] <<
          [link.to, link.to_orient].to_oriented_segment
      end
      line_data[:cigars][0] << link.overlap
    end
    parse_optfields(line_data)
    # <debug> "Path data: #{line_data}"
    rgfa << RGFA::Line::Path.new(line_data)
  end

  def parse_optfield
    fieldname = parse_fixlenstr(2).to_sym
    datatype = parse_fixlenstr(1).to_sym
    value = parse_data_item(datatype.to_sym)
    datatype = :i if INTEGER_DATATYPES.include?(datatype)
    # <debug> "Optfield #{fieldname}:#{datatype}:#{value.inspect}"
    return fieldname, datatype, value
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
    else
      # <assert> false # this should be impossible
    end
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
      c = @io.getc
      if c.nil?
        raise BFA::Reader::FormatError
      elsif c == "\0"
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
    str = @io.read(val_size)
    if str.nil? or str.size < val_size
      raise BFA::Reader::FormatError
    end
    return str
  end

end

require_relative "reader/format_error"
