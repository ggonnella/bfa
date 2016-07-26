require "rgfa"
require "zlib"
require_relative "constants"
require_relative "binary_cigar/encode"
require_relative "four_bit_sequence/encode"

class BFA::Writer

  include BFA::Constants

  # @return [RGFATools::BFAWriter]
  def initialize(filename, compressed=true)
    @template = ""
    @data = []
    file = File.new(filename, "w")
    @io = compressed ? Zlib::GzipWriter.new(file) : file
    @io.print BFA::Constants::MAGIC_STRING
  end

  def encode(rgfa)
    add_headers(rgfa)
    add_segments(rgfa)
    add_links(rgfa)
    add_containments(rgfa)
    add_paths(rgfa)
  end

  def close
    @io.close
  end

  def self.encode(filename, rgfa, compressed=true)
    bw = self.new(filename, compressed)
    bw.encode(rgfa)
    bw.close
    return nil
  end

  private

  def add_headers(rgfa)
    headers_array = rgfa.headers_array
    add_size_of(headers_array)
    headers_array.each do |fieldname, val_type, value|
      add_optfield(fieldname, value, val_type)
    end
    write_data
  end

  def add_optfields(rgfa_line)
    add_size_of(rgfa_line.optional_fieldnames)
    rgfa_line.optional_fieldnames.each do |of|
      add_optfield(of, rgfa_line.get(of), rgfa_line.get_datatype(of))
    end
  end

  def add_segments(rgfa)
    add_size_of(rgfa.segment_names)
    rgfa.segment_names.each_with_index do |segment_name, i|
      s = rgfa.segment!(segment_name)
      add_varlenstr(segment_name)
      add_sequence(s.sequence)
      add_optfields(s)
      write_data
      s.line_id = i
    end
  end

  def add_containments(rgfa)
    add_edges(rgfa, true)
  end

  def add_links(rgfa)
    add_edges(rgfa, false)
  end

  def add_edges(rgfa, containments=false)
    add_size_of(containments ? rgfa.containments : rgfa.links)
    sn = rgfa.segment_names
    link_id = 0
    sn.each_with_index do |segment_name, segment_id|
      if containments
        edges = rgfa.contained_in(segment_name)
      else
        edges = [:+, :-].map do |orientation|
          rgfa.links_from([segment_name, orientation], false)
        end.flatten
      end
      edges.each do |edge|
        dir_id = {:from => segment_id,
                  :to => rgfa.segment(edge.to).line_id}
        [:from, :to].each do |dir|
          dir_id[dir] += 1
          dir_id[dir] = -dir_id[dir] if edge.get(:"#{dir}_orient") == :-
          add_numeric_value(:i, dir_id[dir])
        end
        add_cigar(edge.overlap)
        add_numeric_value(:I, edge.pos) if containments
        add_optfields(edge)
        write_data
        if not containments
          edge.line_id = link_id
          link_id += 1
        end
      end
    end
  end

  def add_paths(rgfa)
    add_size_of(rgfa.paths)
    rgfa.paths.each do |path|
      add_varlenstr(path.path_name)
      links = rgfa.path_links(path)
      # <debug> "Path links: #{links.inspect}"
      n_links = links.size
      n_links = -n_links if path.circular?
      add_numeric_value(:i, n_links)
      link_ids = links.map do |link, link_or|
        line_id = link.line_id + 1
        # <debug> "line_id: #{line_id.inspect}"
        # <debug> "link_or: #{link_or.inspect}"
        link_or ? line_id : -line_id
      end
      # <debug> "link ids: #{link_ids.inspect}"
      add_numeric_values(:i, link_ids, false)
      add_optfields(path)
      write_data
    end
  end

  # Add an optional field to the record
  def add_optfield(fieldname, value, val_type)
    val_type ||= value.gfa_datatype
    add_fixlenstr(fieldname)
    add_fixlenstr(val_type)
    add_data_item(val_type, value)
  end

  def write_data
    @io.print(@data.pack(@template))
    @template = ""
    @data = []
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
    end
    return nil
  end

  def add_sequence(seq)
    if seq == "*"
      add_numeric_value(:I, 0)
    else
      add_size_of(seq)
      add_values(NUMERIC_TEMPLATE_CODE[:C], seq.to_4bits)
    end
  end

  def add_cigar(cigar)
    cigar = cigar.to_cigar
    if cigar.empty?
      add_numeric_value(:I, 0)
    else
      add_numeric_values(:I, cigar.map(&:to_binary))
    end
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
    array = array.parse_datastring(:B) if array.kind_of?(String)
    array = array.to_numeric_array
    st = array.compute_subtype
    add_fixlenstr(st)
    add_numeric_values(st.to_sym, array)
  end

  def add_byte_array(array)
    array = array.parse_datastring(:H) if array.kind_of?(String)
    array = array.to_byte_array
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

  def add_numeric_values(val_type, array, with_size = true)
    # <assert> NUMERIC_TEMPLATE_CODE.has_key?(val_type)
    # <assert> array.kind_of?(Array)
    # <assert> array.each? {|e| e.kind_of?(Numeric)}
    add_size_of(array) if with_size
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
