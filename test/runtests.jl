using Test

include("../parser.jl")

@testset "test_shift" begin
    a = [1, 2, 3, 4]
    @test 1 == shift!(a)
    @test 2 == shift!(a)
    @test 3 == shift!(a)
    @test 4 == shift!(a)
    @test nothing === shift!(a)
end

@testset "test_matchesstring" begin
    re1 = RegexElement(ExactlyOne, Value, 'a')

    @test (true, 1) == matchesstring(re1, "a", 1)
    @test (true, 1) == matchesstring(re1, "ax", 1)
    @test (false, 0) == matchesstring(re1, "b", 1)
    
    re2 = RegexElement(ExactlyOne, Wildcard, "")
    
    @test (true, 1) == matchesstring(re2, "a", 1)
    @test (true, 1) == matchesstring(re2, "abv", 1)
    @test (true, 1) == matchesstring(re2, "x", 1)
    @test (true, 1) == matchesstring(re2, "7", 1)
    @test (false, 0) == matchesstring(re2, "", 1)
end

@testset "parser" begin
    re1 = parse("a")

    @test (true, 1) == test(re1, "a")
    re = parse("a?bc")
    @test test(re, "bc") == (true, 2)
    @test test(re, "abc") == (true, 3)
end
