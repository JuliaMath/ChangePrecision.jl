"""
The `ChangePrecision` module exports a macro `@changeprecision T expression`
that changes the "default" floating-point precision in a given `expression`
to a new floating-point type `T`.
"""
module ChangePrecision

export @changeprecision

const randfuncs = (:rand, :randn, :randexp) # random-number generators
const matfuncs = (:ones, :zeros, :eye) # functions to construct arrays
#from https://docs.julialang.org/en/release-0.6/manual/mathematical-operations/, up to date as of 0.6
const intfuncs = (:/, :\, :inv, :float,
                  # powers logs and roots
                  :√,:∛,:sqrt,:cbrt,:hypot,:exp,:exp2,:exp10,:expm1,:log,:log2,:log10,:log1p,:cis,
                  # trig
                  :sin,    :cos,    :tan,    :cot,    :sec,    :csc,
                  :sinh,   :cosh,   :tanh,   :coth,   :sech,   :csch,
                  :asin,   :acos,   :atan,   :acot,   :asec,   :acsc,
                  :asinh,  :acosh,  :atanh,  :acoth,  :asech,  :acsch,
                  :sinc,   :cosc,   :atan2,
                  :cospi,  :sinpi,
                  # trig in degrees
                  :deg2rad,:rad2deg,
                  :sind,   :cosd,   :tand,   :cotd,   :secd,   :cscd,
                  :asind,  :acosd,  :atand,  :acotd,  :asecd,  :acscd,
                  # special functions
                  :gamma,:lgamma,:lfact,:beta,:lbeta)
const complexfuncs = (:abs, :angle) # functions that give Float64 for Complex{Int}
const binaryfuncs = (:*, :+, :-, :^) # binary functions on irrationals that make Float64
const changefuncs = Set([randfuncs..., matfuncs..., intfuncs..., complexfuncs..., binaryfuncs...])
changeprecision(T, x) = x
changeprecision(T::Type, x::Float64) = parse(T, string(x)) # change float literals
function changeprecision(T, x::Symbol)
    if x ∈ (:Inf, :NaN)
        return :(convert($T, $x))
    else
        return x
    end
end
function changeprecision(T, x::Float64)
    if T === :Float16
        return Float16(x)
    elseif T === :Float32
        return Float32(x)
    elseif T === :Float64
        return x
    elseif T === :BigFloat
        return parse(BigFloat, string(x))
    else
        return :(parse($T, $(string(x))))
    end
end
function changeprecision(T, ex::Expr)
    if Meta.isexpr(ex, :call, 3) && ex.args[1] == :^ && ex.args[3] isa Int
        # mimic Julia 0.6/0.7's lowering to literal_pow
        return Expr(:call, ChangePrecision.literal_pow, T, :^, ex.args[2], Val{ex.args[3]}())
    elseif Meta.isexpr(ex, :call) && ex.args[1] in changefuncs
        return Expr(:call, eval(ChangePrecision, ex.args[1]), T, changeprecision.(T, ex.args[2:end])...)
    elseif Meta.isexpr(ex, :., 2) && ex.args[1] in changefuncs && Meta.isexpr(ex.args[2], :tuple)
        return Expr(:., eval(ChangePrecision, ex.args[1]), Expr(:tuple, T, changeprecision.(T, ex.args[2].args)...))
    else
        return Expr(ex.head, changeprecision.(T, ex.args)...)
    end
end

"""
    @changeprecision T expression

Change the "default" precision in the given `expression` to the floating-point
type `T`.

This changes floating-point literals, integer expressions like `1/3`,
random-number functions like `rand`, and matrix constructors like `ones`
to default to the new type `T`.

For example,
```
@changeprecision Float32 begin
    x = 7.3
    y = 1/3
    z = rand() .+ ones(3,4)
end
```
uses `Float32` precision for all of the expressions in `begin ... end`.
"""
macro changeprecision(T, expr)
    esc(changeprecision(T, expr))
end

# define our own versions of rand etc. that override the default type,
# which which still respect a type argument if it is explicitly provided
for f in randfuncs
    @eval begin
        $f(T) = Base.$f(T)
        $f(T, dims::Integer...) = Base.$f(T, dims...)
        $f(T, dims::Tuple{<:Integer}) = Base.$f(T, dims)
        $f(T, rng::AbstractRNG, dims::Integer...) = Base.$f(rng, T, dims...)
        $f(T, rng::AbstractRNG, dims::Tuple{<:Integer}) = Base.$f(rng, T, dims)
        $f(T, args...) = Base.$f(args...)
    end
end

# similarly for array constructors like ones
for f in matfuncs
    @eval begin
        $f(T) = Base.$f(T, dims...)
        $f(T, dims::Integer...) = Base.$f(T, dims...)
        $f(T, dims::Tuple{<:Integer}) = Base.$f(T, dims)
        $f(T, args...) = Base.$f(args...)
    end
end

# integer-like types that get converted to Float64 by various functions
const HWInt = Union{Bool,Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128}
const RatLike = Union{Rational{<:HWInt}, Complex{<:Rational{<:HWInt}}}
const IntLike = Union{HWInt, Complex{<:HWInt}}
const Promotable = Union{IntLike, RatLike, Irrational}

# we want to change expressions like 1/2 to produce the new floating-point type
for f in intfuncs
    @eval begin
        $f(T, n::Promotable) = Base.$f(tofloat(T, n))
        $f(T, m::Promotable, n::Promotable) = Base.$f(tofloat(T, m), tofloat(T, n))
        $f(T, args...) = Base.$f(args...)
    end
end

# exception to intfuncs above: division on rationals produces an exact rational
inv(T, x::RatLike) = Base.inv(x)
/(T, y::IntLike, x::RatLike) = Base.:/(y, x)
\(T, x::RatLike, y::IntLike) = Base.:\(x, y)
/(T, y::RatLike, x::IntLike) = Base.:/(y, x)
\(T, x::IntLike, y::RatLike) = Base.:\(x, y)
/(T, y::RatLike, x::RatLike) = Base.:/(y, x)
\(T, x::RatLike, y::RatLike) = Base.:\(x, y)

for f in complexfuncs
    @eval begin
        $f(T, z::Union{Complex{<:HWInt},Complex{<:Rational{<:HWInt}}}) = Base.$f(tofloat(T, z))
        $f(T, args...) = Base.$f(args...)
    end
end

for f in binaryfuncs
    @eval begin
        $f(T, x::Irrational, y::Promotable) = Base.$f(tofloat(T, x), tofloat(T, y))
        $f(T, x::Promotable, y::Irrational) = Base.$f(tofloat(T, x), tofloat(T, y))
        $f(T, x::Irrational, y::Irrational) = Base.$f(tofloat(T, x), tofloat(T, y))
        $f(T, args...) = Base.$f(args...)
    end
end
-(T::Type, x::Irrational) = Base.:-(tofloat(T, x))

^(T, x::Promotable, y::Union{RatLike,Complex{<:HWInt}}) = Base.:^(tofloat(T, x), y)

# e^x is handled specially
const esym = VERSION < v"0.7.0-DEV.1592" ? :e : :ℯ # changed in JuliaLang/julia#23427
^(T, x::Irrational{esym}, y::Promotable) = Base.exp(tofloat(T, y))
literal_pow(T, op, x::Irrational{esym}, ::Val{n}) where {n} = Base.exp(tofloat(T, n))

# literal integer powers are specially handled in Julia
if VERSION < v"0.7.0-DEV.843" # JuliaLang/julia#22475
    literal_pow(T, op, x::Irrational, ::Val{n}) where {n} = Base.literal_pow(op, tofloat(T, x), Val{n})
    @inline literal_pow(T, op, x, ::Val{n}) where {n} = Base.literal_pow(op, x, Val{n})
else
    literal_pow(T, op, x::Irrational, p) = Base.literal_pow(op, tofloat(T, x), p)
    @inline literal_pow(T, op, x, p) = Base.literal_pow(op, x, p)
end

@inline tofloat(T, x) = T(x)
@inline tofloat(::Type{T}, x::Complex) where {T<:Real} = Complex{T}(x)

end # module
