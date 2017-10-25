using ChangePrecision
using Base.Test

@testset "basic tests" begin
    for T in (Float16, Float32, BigFloat)
        @test T(1)/T(3) == @changeprecision(T, 1/3)::T
        @test T(1) == @changeprecision(T, float(1))::T
        @test parse(T, "1.234") == @changeprecision(T, 1.234)::T
        if T != BigFloat
            @test @changeprecision(T, rand()) isa T
            @test @changeprecision(T, rand(Float64)) isa Float64
        end
        @test @changeprecision(T, ones(2,3)) isa Matrix{T}
        @test @changeprecision(T, ones(Float64, 2,3)) isa Matrix{Float64}
        @test @changeprecision(T, sin(1)) isa T
        @test @changeprecision(T, sqrt(2)) isa T
        @test isequal(@changeprecision(T, Inf)::T, Inf)
        @test isequal(@changeprecision(T, NaN)::T, NaN)
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
    @test @changeprecision(Float32, pi^2) === Float32(pi)^2
    @test @changeprecision(Float32, pi^2) === Float32(pi)^2
    @test @changeprecision(Float32, euler^2) === @changeprecision(Float32, euler^(3-1)) === exp(Float32(2))
end

@testset "powers" begin
    @test @changeprecision(Float32, 3^2) === @changeprecision(Float32, 3^(3-1)) === 9
    @test @changeprecision(Float32, 3^(1//2)) === sqrt(Float32(3))
    @test @changeprecision(Float32, 3^(1+2im)) === Float32(3)^(1+2im)
end
