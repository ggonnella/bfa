require_relative "../lib/bfa"
require "test/unit"
require "tempfile"

class TestBFA < Test::Unit::TestCase

  def test_test1_encode_decode
    r = RGFA.from_file("test/testdata/test1.gfa")
    t = Tempfile.new("bfa")
    t.close
    BFA::Writer.encode(t.path, r)
    b = BFA::Reader.parse(t.path)
    t.unlink
  end

end
