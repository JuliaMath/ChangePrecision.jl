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
    end
end
