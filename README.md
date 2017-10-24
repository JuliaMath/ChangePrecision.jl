# ChangePrecision

[![Build Status](https://travis-ci.org/stevengj/ChangePrecision.jl.svg?branch=master)](https://travis-ci.org/stevengj/ChangePrecision.jl)

[![Coverage Status](https://coveralls.io/repos/stevengj/ChangePrecision.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/stevengj/ChangePrecision.jl?branch=master)

[![codecov.io](http://codecov.io/github/stevengj/ChangePrecision.jl/coverage.svg?branch=master)](http://codecov.io/github/stevengj/ChangePrecision.jl?branch=master)

This package makes it easy to change the "default" precision of a large body of Julia code, simply by prefixing it with the `@changeprecision T expression` macro, for example:

```julia
@changeprecision Float32 begin
    x = 7.3
    y = 1/3
    z = rand() .+ ones(3,4)
end
```

In particular, floating-point literals like `7.3` are reinterpreted as the requested type `Float32`, operations like `/` that convert integer arguments to `Float64` instead convert to `Float32`, and random-number or matrix constructors like `rand` and `ones` default to `Float32` instead of `Float64`.

Code that explicitly specifies a type, e.g. `rand(Float64)`, is unaffected by `@changeprecision`.
