require "rgfa"
require_relative "../bfa/record"

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
