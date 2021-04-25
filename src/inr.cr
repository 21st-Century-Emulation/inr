require "crest"
require "json"
require "kemal"

# You can use JSON.mapping to directly create an object from JSON
class User
  include JSON::Serializable

  property username : String, password : String
end

class CpuFlags
  include JSON::Serializable

  property sign : Bool, zero : Bool, auxCarry : Bool, parity : Bool, carry : Bool
end

class CpuState
  include JSON::Serializable

  property a : UInt8, b : UInt8, c : UInt8, d : UInt8, e : UInt8, h : UInt8, l : UInt8, stackPointer : UInt16, programCounter : UInt16, cycles : UInt64, flags : CpuFlags, interruptsEnabled : Bool
end

class Cpu
  include JSON::Serializable

  property opcode : UInt8, id : String, state : CpuState
end  

VERSION = "0.1.0"

READ_MEMORY_API = ENV["READ_MEMORY_API"]
WRITE_MEMORY_API = ENV["WRITE_MEMORY_API"]

get "/status" do
  "Healthy"
end

get "/api/v1/debug/readMemory" do |env|
  (env.params.query["address"].to_i & 0xFF).to_s
end

post "/api/v1/debug/writeMemory" do |env|
  puts env.params.query["address"] + "=" + env.params.query["value"]
end

post "/api/v1/execute" do |env|
  cpu = Cpu.from_json env.request.body.not_nil!
  opcode = cpu.opcode
  state = cpu.state

  state.cycles &+= 5
  case opcode
  when 0x04 then # INR B
    state.b &+= 1
    set_flags(state.b, state.flags)
  when 0x0C then # INR C
    state.c &+= 1
    set_flags(state.c, state.flags)
  when 0x14 then # INR D
    state.d &+= 1
    set_flags(state.d, state.flags)
  when 0x1C then # INR E
    state.e &+= 1
    set_flags(state.e, state.flags)
  when 0x24 then # INR H
    state.h &+= 1
    set_flags(state.h, state.flags)
  when 0x2C then # INR L
    state.l &+= 1
    set_flags(state.b, state.flags)
  when 0x34 then # INR (HL)
    address = (state.h.to_u16 << 8) | state.l.to_u16
    get_request = Crest.get(READ_MEMORY_API, params: {:id => cpu.id, :address => address.to_i})
    value = get_request.body.to_u8 &+ 1
    set_flags(value, state.flags)
    Crest.post(WRITE_MEMORY_API, params: {:id => cpu.id, :address => address.to_i, :value => value.to_i})
    state.cycles &+= 5 # 5 additional cycles for memory access
  when 0x3C then # INR A
    state.a &+= 1
    set_flags(state.a, state.flags)
  end

  cpu.to_json
end

private def set_flags(x : UInt8 | Int32, flags : CpuFlags)
  flags.sign = x.bit(7) == 1
  flags.zero = x.zero?
  flags.parity = ((0..7).count { |i| x.bit(i) == 1 }).even?
  flags.auxCarry = (x & 0xF) + 1 > 0xF
end

Kemal.config.port = 8080
Kemal.run
