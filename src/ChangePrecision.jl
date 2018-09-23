VERSION < v"0.7.0-beta2.199" && __precompile__()

"""
The `ChangePrecision` module exports a macro `@changeprecision T expression`
that changes the "default" floating-point precision in a given `expression`
to a new floating-point type `T`.
"""
module ChangePrecision

import Random, Statistics, LinearAlgebra
using Random: AbstractRNG

## Note: code in this module must be very careful with math functions,
#        because we've defined module-specific versions of very basic
#        functions like + and *.   Call Base.:+ etcetera if needed.

export @changeprecision

############################################################################
# The @changeprecision(T, expr) macro, below, takes calls to
# functions f that default to producing Float64 (e.g. from integer args)
# and converts them to calls to ChangePrecision.f(T, args...).  Then
# we implement our f(T, args...) to default to T instead.  The following
# are a list of function calls to transform in this way.

const randfuncs = (:rand, :randn, :randexp) # random-number generators
const matfuncs = (:ones, :zeros) # functions to construct arrays
const complexfuncs = (:abs, :angle) # functions that give Float64 for Complex{Int}
const binaryfuncs = (:*, :+, :-, :^) # binary functions on irrationals that make Float64

# math functions that convert integer-like arguments to floating-point results
# (from https://docs.julialang.org/en/release-0.6/manual/mathematical-operations/, up to date as of 0.6)
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
                  )


# functions that convert integer arrays to floating-point results
const statfuncs = (:mean, :std, :stdm, :var, :varm, :median, :cov, :cor)
const linalgfuncs = (:opnorm, :norm, :normalize,
                     :factorize, :cholesky, :bunchkaufman, :ldlt, :lu, :qr, :lq,
                     :eigen, :eigvals, :eigfact, :eigmax, :eigmin, :eigvecs,
                     :hessenberg, :schur, :svd, :svdvals,
                     :cond, :condskeel, :det, :logdet, :logabsdet,
                     :pinv, :nullspace, :lyap, :sylvester)

# functions to change to ChangePrecision.func(T, ...) calls:
const changefuncs = Set([randfuncs..., matfuncs...,
                         intfuncs..., complexfuncs...,
                         statfuncs..., linalgfuncs...,
                         binaryfuncs..., :include])

############################################################################

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
    else
        return :(parse($T, $(string(x))))
    end
end
function changeprecision(T, ex::Expr)
    if Meta.isexpr(ex, :call, 3) && ex.args[1] == :^ && ex.args[3] isa Int
        # mimic Julia 0.6/0.7's lowering to literal_pow
        return Expr(:call, ChangePrecision.literal_pow, T, :^, changeprecision(T, ex.args[2]), Val{ex.args[3]}())
    elseif Meta.isexpr(ex, :call, 2) && ex.args[1] == :include
        return :($include($T, @__MODULE__, $(ex.args[2])))
    elseif Meta.isexpr(ex, :call) && ex.args[1] in changefuncs
        return Expr(:call, Core.eval(ChangePrecision, ex.args[1]), T, changeprecision.(T, ex.args[2:end])...)
    elseif Meta.isexpr(ex, :., 2) && ex.args[1] in changefuncs && Meta.isexpr(ex.args[2], :tuple)
        return Expr(:., Core.eval(ChangePrecision, ex.args[1]), Expr(:tuple, T, changeprecision.(T, ex.args[2].args)...))
    elseif Meta.isexpr(ex, :call, 3) && ex.args[1] == :^ && ex.args[3] isa Int
    else
        return Expr(ex.head, changeprecision.(T, ex.args)...)
    end
end

# calls to include(f) are changed to include(T, mod, f) so that
# @changeprecision can apply recursively to included files.
function include(T, mod, filename::AbstractString)
    # use the undocumented parse_input_line function so that we preserve
    # the filename and line-number information.
    s = string("begin; ", read(filename, String), "\nend\n")
    expr = Base.parse_input_line(s, filename=filename)
    Core.eval(mod, changeprecision(T, expr))
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

############################################################################

# integer-like types that get converted to Float64 by various functions
const HWInt = Union{Bool,Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128}
const RatLike = Union{Rational{<:HWInt}, Complex{<:Rational{<:HWInt}}}
const IntLike = Union{HWInt, Complex{<:HWInt}}
const IntRatLike = Union{IntLike,RatLike}
const Promotable = Union{IntLike, RatLike, Irrational}
const PromotableNoRat = Union{IntLike, Irrational}

@inline tofloat(T, x) = T(x)
@inline tofloat(::Type{T}, x::Complex) where {T<:Real} = Complex{T}(x)
@inline tofloat(T, x::AbstractArray) = copyto!(similar(x, T), x)
@inline tofloat(::Type{T}, x::AbstractArray{<:Complex}) where {T<:Real} = copyto!(similar(x, Complex{T}), x)

###########################################################################
# ChangePrecision.f(T, args...) versions of Base.f(args...) functions.

# define our own versions of rand etc. that override the default type,
# which which still respect a type argument if it is explicitly provided
for f in randfuncs
    @eval begin
        $f(T) = Random.$f(T)
        $f(T, dims::Integer...) = Random.$f(T, dims...)
        $f(T, dims::Tuple{<:Integer}) = Random.$f(T, dims)
        $f(T, rng::AbstractRNG, dims::Integer...) = Random.$f(rng, T, dims...)
        $f(T, rng::AbstractRNG, dims::Tuple{<:Integer}) = Random.$f(rng, T, dims)
        $f(T, args...) = Random.$f(args...)
    end
end

# similarly for array constructors like ones
for f in matfuncs
    @eval begin
        $f(T) = Base.$f(T)
        $f(T, dims::Integer...) = Base.$f(T, dims...)
        $f(T, dims::Tuple{<:Integer}) = Base.$f(T, dims)
        $f(T, args...) = Base.$f(args...)
    end
end

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
for f in (:+, :*) # these functions can accept 3+ arguments
    # FIXME: these methods may be slow compared to the built-in + or *
    #        because they do less inlining?
    @eval begin
        @inline $f(T, x::Promotable, y, z, args...) = $f(T, x, $f(T, y, z, args...))
        @inline $f(T, x::IntRatLike, y::IntRatLike, z::IntRatLike, args::IntRatLike...) = Base.$f(x, y, z, args...)
    end
end

^(T, x::Union{AbstractMatrix{<:Promotable},Promotable}, y::Union{RatLike,Complex{<:HWInt}}) = Base.:^(tofloat(T, x), y)

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

for f in (statfuncs...,linalgfuncs...)
    m = f ∈ statfuncs ? :Statistics : :LinearAlgebra
    # for functions like factorize, if we are converting the matrix to floating-point
    # anyway then we might as well call factorize! instead to overwrite our temp array:
    if f ∈ (:factorize, :cholesky, :bunchkaufman, :ldlt, :lu, :qr, :lq, :eigen, :svd, :eigvals!, :svdvals!, :median)
        f! = Symbol(f, :!)
        @eval begin
            $f(T, x::AbstractArray{<:Promotable}, args...; kws...) = $m.$f!(tofloat(T, x), args...; kws...)
            $f(T, x::AbstractArray{<:Promotable}, y::AbstractArray{<:Promotable}, args...; kws...) = $m.$f!(tofloat(T, x), tofloat(T, y), args...; kws...)
        end
    else
        @eval begin
            $f(T, x::AbstractArray{<:Promotable}, args...; kws...) = $m.$f(tofloat(T, x), args...; kws...)
            $f(T, x::AbstractArray{<:Promotable}, y::AbstractArray{<:Promotable}, args...; kws...) = $m.$f(tofloat(T, x), tofloat(T, y), args...; kws...)
        end
    end
    @eval begin
        $f(T, x::AbstractArray{<:Promotable}, y::AbstractArray, args...; kws...) = $m.$f(x, y, args...; kws...)
        $f(T, args...; kws...) = $m.$f(args...; kws...)
    end
end
for f in (:varm, :stdm) # look at type of second (scalar) argument
    @eval begin
        $f(T, x::AbstractArray{<:Promotable}, m::Union{AbstractFloat,Complex{<:AbstractFloat}}, args...; kws...) = Statistics.$f(x, m, args...; kws...)
        $f(T, x::AbstractArray{<:PromotableNoRat}, m::PromotableNoRat, args...; kws...) = Statistics.$f(tofloat(T, x), tofloat(T, m), args...; kws...)
    end
end
inv(T, x::AbstractArray{<:PromotableNoRat}) = Base.inv(tofloat(T, x))
/(T, x::AbstractArray{<:Promotable}, y::Union{PromotableNoRat,AbstractArray{<:PromotableNoRat}}) = Base.:/(tofloat(T, x), tofloat(T, y))
\(T, y::Union{PromotableNoRat,AbstractArray{<:PromotableNoRat}}, x::AbstractArray{<:Promotable}) = Base.:\(tofloat(T, y), tofloat(T, x))

# more array functions that are exact for rationals: don't convert
for f in (:mean, :median, :var, :std, :cor, :cov, :ldlt, :lu)
    m = f ∈ statfuncs ? :Statistics : :LinearAlgebra
    @eval begin
        $f(T, x::AbstractArray{<:RatLike}, y::AbstractArray{<:Promotable}, args...; kws...) = $m.$f(tofloat(T, x), tofloat(T, y), args...; kws...)
        $f(T, x::AbstractArray{<:RatLike}, y::AbstractArray{<:RatLike}, args...; kws...) = $m.$f(x, y, args...; kws...)
        $f(T, x::AbstractArray{<:RatLike}, args...; kws...) = $m.$f(x, args...; kws...)
    end
end

############################################################################

end # module
