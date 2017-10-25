"""
The `ChangePrecision` module exports a macro `@changeprecision T expression`
that changes the "default" floating-point precision in a given `expression`
to a new floating-point type `T`.
"""
module ChangePrecision

export @changeprecision

const randfuncs = (:rand, :randn, :randexp) # random-number generators
const matfuncs = (:ones, :zeros, :eye) # functions to construct arrays
const intfuncs = (:/, :inv, :sqrt, :√, :float, :sin, :cos, :tan, :asin, :acos, :acosh, :atanh, :log, :log2, :log10,
                  :lgamma, :log1p, :cbrt, :sinh, :cosh, :tanh, :atan, :asinh, :exp2, :expm1) # functions that turn integers into floats
const changefuncs = Set([randfuncs..., matfuncs..., intfuncs...])

changeprecision(T, x) = x
changeprecision(T::Type, x::Float64) = parse(T, string(x)) # change float literals
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
    if Meta.isexpr(ex, :call) && ex.args[1] in changefuncs
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
const IntLike = Union{<:HWInt, Complex{<:HWInt}}

# we want to change expressions like 1/2 to produce the new floating-point type
for f in intfuncs
    @eval begin
        $f(T, n::IntLike) = Base.$f(tofloat(T, n))
        $f(T, m::IntLike, n::IntLike) = Base.$f(tofloat(T, m), tofloat(T, n))
        $f(T, args...) = Base.$f(args...)
    end
end

@inline tofloat(T, x) = T(x)
@inline tofloat(::Type{T}, x::Complex) where {T<:Real} = Complex{T}(x)

end # module
