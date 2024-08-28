module receiver

abstract type Receiver end

struct r1{T} <: Receiver
  w::T
  c::UInt
  next::Function
end

struct r2{S,T} <: Receiver
  w::S
  x::T
  c::UInt
  next::Function
end

struct r3{R,S,T} <: Receiver
  w::R
  x::S
  y::T
  c::UInt
  next::Function
end

struct r4{Q,R,S,T} <: Receiver
  w::Q
  x::R
  y::S
  z::T
  c::UInt
  next::Function
end



end # module
