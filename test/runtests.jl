using ChangePrecision
using Test, LinearAlgebra, Statistics

≡(x::T,y::T) where {T<:Number} = isequal(x, y)
≡(x::T,y::T) where {T} = x == y
≡(x, y) = false

@testset "basic tests" begin
    for T in (Float16, Float32, BigFloat)
        @test T(1)/T(3) ≡ @changeprecision(T, 1/3)
        @test T(1) ≡ @changeprecision(T, float(1))
        @test parse(T, "1.234") ≡ @changeprecision(T, 1.234)
        if T != BigFloat
            @test @changeprecision(T, rand()) isa T
            @test @changeprecision(T, rand(Float64)) isa Float64
        end
        @test @changeprecision(T, ones(2,3)) ≡ ones(T,2,3)
        @test @changeprecision(T, ones()) ≡ ones(T)
        @test @changeprecision(T, ones(Float64, 2,3)) ≡ ones(Float64,2,3)
        @test @changeprecision(T, sin(1)) ≡ sin(T(1))
        @test @changeprecision(T, sqrt(2)) ≡ sqrt(T(2))
        @test @changeprecision(T, Inf) ≡ T(Inf)
        @test @changeprecision(T, NaN) ≡ T(NaN)
    end
end

@testset "rationals" begin
    @test @changeprecision(Float32, sqrt(2//3)) === sqrt(Float32(2//3))
    @test @changeprecision(Float32, inv(2//3)) === 3//2
    @test @changeprecision(Float32, (2//3) / 2) === 1//3
    @test @changeprecision(Float32, 2 / (4//3)) === 3//2
    @test @changeprecision(Float32, (2//3) / (4//3)) === 1//2
    @test @changeprecision(Float32, (2//3) \ (4//3)) === 2//1
end

@testset "complex" begin
    @test @changeprecision(Float32, abs(1+1im)) === sqrt(Float32(2))
    @test @changeprecision(Float32, angle(1+0im)) === Float32(0)
end

const euler = VERSION < v"0.7.0-DEV.1592" ? e : ℯ # changed in JuliaLang/julia#23427

@testset "irrational" begin
    @test @changeprecision(Float32, sqrt(pi)) === sqrt(Float32(pi))
    @test @changeprecision(Float32, pi/3) === Float32(pi)/3
    @test @changeprecision(Float32, 2pi) === Float32(pi)*2
    @test @changeprecision(Float32, pi+2) === Float32(pi)+2
    @test @changeprecision(Float32, -pi) === -Float32(pi)
    @test @changeprecision(Float32, 2Float64(pi)) === Float64(pi)*2
    @test @changeprecision(Float32, 2*2*2*2*2*Float32(pi)) === @changeprecision(Float32,Float32(pi)*2*2*2*2*2)=== 32*Float32(pi)
    @test @changeprecision(Float32, pi^2) === Float32(pi)^2
    @test @changeprecision(Float32, pi^2) === Float32(pi)^2
    @test @changeprecision(Float32, euler^2) === @changeprecision(Float32, euler^(3-1)) === exp(Float32(2))
end

@testset "powers" begin
    @test @changeprecision(Float32, 3^2) === @changeprecision(Float32, 3^(3-1)) === 9
    @test @changeprecision(Float32, 3^(1//2)) === sqrt(Float32(3))
    @test @changeprecision(Float32, 3^(1+2im)) === Float32(3)^(1+2im)
    @test @changeprecision(Float32, 0.5^2) === 0.25f0
end

@testset "arrays" begin
    @test @changeprecision(Float32, mean([1,3])) === @changeprecision(Float32, median([1,3])) === 2.0f0
    @test @changeprecision(Float32, norm([1,3],Inf)) === 3.0f0
    @test @changeprecision(Float32, varm([1,3],2)) === @changeprecision(Float32, varm([1,3],2.0)) === 2.0f0
    @test @changeprecision(Float32, varm([1,3], Float64(2))) === 2.0
    @test @changeprecision(Float32, [2,4]/2) ≡ @changeprecision(Float32, 2\[2,4]) ≡ Float32[1,2]
    @test @changeprecision(Float32, mean([1//1,3//1])) === 2//1
end

@testset "matrices" begin
    @test @changeprecision(Float32, inv(I+zeros(Float64,2,2))) ≡ I+zeros(Float64,2,2)
    @test @changeprecision(Float32, (I+zeros(Int,2,2)) \ (1:2)) ≡ Float32[1,2]
    @test @changeprecision(Float32, [1,2]' / (I+zeros(Int,2,2))) ≡ Float32[1,2]'
    @test @changeprecision(Float32, eigvals(I+zeros(Int,2,2))) ≡ @changeprecision(Float32, eigvals(I+zeros(Rational{Int},2,2))) ≡ eigvals(I+zeros(Float32,2,2))
    @test @changeprecision(Float32, norm(I+zeros(Int,2,2))) ≡ @changeprecision(Float32, norm(I+zeros(Rational{Int},2,2))) ≡ norm(I+zeros(Float32,2,2))
end

module Foo
using ChangePrecision
@changeprecision Float32 include("foo.jl")
end
import .Foo
@testset "include" begin
    @test Foo.foo(1) === 1.0f0 / 3
    @test Foo.foo(1.0) === 1.0 / 3
end

@testset "bigfloat" begin
    @changeprecision BigFloat foobar(x) = pi * x * 0.1
    for p in (50, 100, 1000)
        setprecision(p) do
            @test foobar(3) ≡ big(pi) * 3 * parse(BigFloat, "0.1")
        end
    end
end
