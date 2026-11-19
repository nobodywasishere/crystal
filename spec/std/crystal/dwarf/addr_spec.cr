require "spec"
require "crystal/dwarf/addr"

describe Crystal::DWARF::Addr do
  it "skips a segment selector in each entry" do
    bytes = Bytes[0xaa, 0, 0, 0xbb, 0, 0]
    IO::ByteFormat::SystemEndian.encode(0x1234_u16, bytes[1, 2])
    IO::ByteFormat::SystemEndian.encode(0x5678_u16, bytes[4, 2])

    addresses = Crystal::DWARF::Addr.new(bytes, 2_u8, 1_u8)
    addresses.address_at(0_u32).should eq(0x1234)
    addresses.address_at(1_u32).should eq(0x5678)
  end
end
