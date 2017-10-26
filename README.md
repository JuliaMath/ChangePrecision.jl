# ChangePrecision

[![Build Status](https://travis-ci.org/stevengj/ChangePrecision.jl.svg?branch=master)](https://travis-ci.org/stevengj/ChangePrecision.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/erbe16srnav0wrfu?svg=true)](https://ci.appveyor.com/project/StevenGJohnson/changeprecision-jl)

This package makes it easy to change the "default" precision of a large body of Julia code, simply by prefixing it with the `@changeprecision T expression` macro, for example:

```julia
@changeprecision Float32 begin
    x = 7.3
    y = 1/3
    z = rand() .+ ones(3,4)
end
```

In particular, floating-point literals like `7.3` are reinterpreted as the requested type `Float32`, operations like `/` that convert integer arguments to `Float64` instead convert to `Float32`, and random-number or matrix constructors like `rand` and `ones` default to `Float32` instead of `Float64`.
Several other cases are handled as well: arithmetic with irrational constants like `pi`, linear-algebra functions (like `inv`) on integer matrices, etcetera.

The `@changeprecision` transformations are applied recursively to any `include(filename)` call, so that you can simply do `@changeprecision Float32 include("mycode.jl")` to run a whole script `mycode.jl` in `Float32` default precision.

Code that explicitly specifies a type, e.g. `rand(Float64)`, is unaffected by `@changeprecision`.

Note that only expressions that *explicitly appear* in the `expression` (or code inserted by `include`) are converted by `@changeprecision`.  Code *hidden inside* external functions that are called is not affected.
