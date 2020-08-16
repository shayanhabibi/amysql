import unittest
include async_mysql

proc hexstr(s: string): string =
  const HexChars = "0123456789abcdef"
  result = newString(s.len * 2)
  for pos, c in s:
    var n = ord(c)
    result[pos * 2 + 1] = HexChars[n and 0xF]
    n = n shr 4
    result[pos * 2] = HexChars[n]

suite "test_param_pack":
  test "Testing parameter packing":
  
    let dummy_param = ColumnDefinition()
    var sth: PreparedStatement
    new(sth)
    sth.statement_id = ['\0', '\xFF', '\xAA', '\x55' ]
    sth.parameters = @[dummy_param, dummy_param, dummy_param, dummy_param, dummy_param, dummy_param, dummy_param, dummy_param]
    # packing small numbers, 1:
    let buf = formatBoundParams(sth, [ asParam(0), asParam(1), asParam(127), asParam(128), asParam(255), asParam(256), asParam(-1), asParam(-127) ])
    let p1 = "000000001700ffaa5500010000000001" &  # packet header
           "01800180018001800180028001000100" &  # wire type info
           "00017f80ff0001ff81"                 # packed values
    check p1 == hexstr(buf)
    # packing numbers and NULLs:
    sth.parameters = sth.parameters & dummy_param
    let buf2 = formatBoundParams(sth, [ asParam(-128), asParam(-129), asParam(-255), asParam(nil), asParam(nil), asParam(-256), asParam(-257), asParam(-32768), asParam(nil)  ])
    let p2 = "000000001700ffaa550001000000180101" &  # packet header
           "010002000200020002000200" &            # wire type info
           "807fff01ff00fffffe0080"               # packed values
    check p2 == hexstr(buf2)

    # more values:
    let buf3 = formatBoundParams(sth, [ asParam("hello"), asParam(nil),
      asParam(0xFFFF), asParam(0xF1F2F3), asParam(0xFFFFFFFF), asParam(0xFFFFFFFFFF),
      asParam(-12885), asParam(-2160069290), asParam(low(int64) + 512) ])
    let p3 = "000000001700ffaa550001000000020001" &  # packet header
           "fe000280038003800880020008000800"   &  # wire type info
           "0568656c6c6ffffff3f2f100ffffffffffffffffff000000abcd56f53f7fffffffff0002000000000080"
    check p3 == hexstr(buf3)