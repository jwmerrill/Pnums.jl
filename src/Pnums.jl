# Pnum stands for either "prototype Unum," or "projective number." I
# haven't totally decided yet. I don't want to call these Unums yet
# because I've only implemented a tiny bit of the Unum 2.0 proposal,
# and I'm implementing some things that aren't in it (AFAICT).
#
# Pnums are exactly as described by Gustafson for Unums 2.0.
#
# Pbounds represent intervals of the stereographic circle (i.e. the
# projective real line). They are encoded as 2 Pnums, and you traverse
# them counter-clockwise from the first value to the second value.
#
# This means that there are n redundant representations of the entire
# set.
#
# The top two bits of a Pbound are a tag, which is set to 00 for normal
# Pbounds, and 10 for the empty set. The second bit of the tag is
# currently unused. When the empty set tag is present, the rest of the
# Pbound has no interpretation.
#
# One idea I had for the second tag bit is to allow a distinction
# between a completely empty set, the result of an operation over an
# interval that maps partially to the empty set. E.g. to encode the
# difference between sqrt(pb"(-1, 1)") and sqrt(pb"(0, 1)"). In the
# first case, part of the input maps to the real line, and part of it
# does not. In the second case, none of the input maps to the real
# line.

module Pnums

# 000 -> [0, 0]
# 001 -> (0, 1)
# 010 -> [1, 1]
# 011 -> (1, /0)
# 100 -> [/0, /0]
# 101 -> (/0, -1)
# 110 -> [-1, -1]
# 111 -> (-1, 0)

# Store unums in a byte with 5 leading zeros
# Store ubounds in a byte
# Store SOPNs in a byte
#
# Interesting that for these numbers, a ubound and a SOPN take the same
# number of bytes to represent
immutable Pnum
  v::UInt8
  Pnum(v) = new(UInt8(v) & 0x07) # TODO magic 00000111 bitmask
end

Base.isfinite(x::Pnum) = x.v != 0x04 # TODO magic number for infinity
isexact(x::Pnum) = (x.v & 0x01) == 0x00
const infty = Pnum(0x04)

const exacts = [-1//1, 0//1, 1//1]

function exactvalue(x::Pnum)
  if !isfinite(x)
    1//0
  else
    exacts[mod((x.v >> 1) + 2, 4)]
  end
end

function Base.convert(::Type{Pnum}, x::Real)
  isinf(x) && return infty
  r = searchsorted(exacts, x)
  if first(r) == last(r)
    return Pnum(UInt8(mod(2*first(r) - 4, 8)))
  elseif first(r) > length(exacts)
    return prev(infty)
  elseif last(r) == 0
    return next(infty)
  else
    return next(Pnum(UInt8(mod(2*last(r) - 4, 8))))
  end
end

Base.(:-)(x::Pnum) = Pnum(-x.v)
# Negate and rotate 180 degrees
recip(x::Pnum) = Pnum(-x.v - 0x04)

# Next and prev move us clockwise around the stereographic circle
next(x::Pnum) = Pnum(x.v + one(x.v))
prev(x::Pnum) = Pnum(x.v - one(x.v))

immutable Pbound
  v::UInt8
end

# TODO, 3 is a magic number (the number of bits in our Pnums)
Pbound(x::Pnum, y::Pnum) = Pbound((x.v << 3) | y.v)
unpack(x::Pbound) = (Pnum(x.v >> 3), Pnum(x.v))
# TODO, 0xc0 is a magic number: "11000000", the first two bits of a byte
tag(x::Pbound) = Pbound(x.v & 0xc0)

# TODO, 0x80 is "11000000", checks top bit
isempty(x::Pbound) = (x.v & 0x80) == 0x80
function iseverything(x::Pbound)
  x1, x2 = unpack(x)
  mod(x1.v - x2.v, 0x08) == one(x.v)
end

const empty = Pbound(0x80)
const everything = Pbound(Pnum(0x00), Pnum(0xff))

function Base.convert(::Type{Pbound}, x::Real)
  x1 = convert(Pnum, x)
  Pbound(x1, x1)
end

function Base.(:-)(x::Pbound)
  isempty(x) && return empty
  x1, x2 = unpack(x)
  Pbound(-x2, -x1)
end

function recip(x::Pbound)
  isempty(x) && return empty
  x1, x2 = unpack(x)
  Pbound(recip(x2), recip(x1))
end

function Base.complement(x::Pbound)
  isempty(x) && return everything
  iseverything(x) && return empty
  x1, x2 = unpack(x)
  Pbound(next(x2), prev(x1))
end

function Base.in(y::Pnum, x::Pbound)
  isempty(x) && return false
  x1, x2 = unpack(x)
  y.v - x1.v <= x2.v - x1.v
end

# Arithmetic:
# Make tables for + and *. They will be 8x8 arrays of Pbounds.
# All arithmetic on "nothing" produces "nothing"
# Ways to produce "everything":
#   * /0 + /0
#   * 0*/0 or /0*0
#   * everything*(something except 0 or /0)
#   * everything + something
# Multiplying 0 or /0 by something (i.e. not nothing) produces 0 or /0

# Need to implement a way of coercing point values into Pnums. Binary search
# on exact values is probably the way to go.

immutable Sopn
  v::UInt8
end

include("./io.jl")

export Pnum, Pbound, @pn_str, @pb_str, isexact, recip

end
