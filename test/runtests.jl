using Test

import Base.==

include("../parser.jl")

Base.:(==)(a::RegexElement, b::RegexElement) = begin
    a.quantifier == b.quantifier && 
    a.value == b.value && 
    a.type == b.type
end

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

@testset "test_parse" begin
    str = "a"
    @test RegexElement(ExactlyOne, Value, 'a') == parse(str)[1]
    @test 1 == length(parse(str))

    str2 = "abc"
    @test 3 == length(parse(str2))
    @test begin
        RegexElement(ExactlyOne, Value, 'a') == parse(str2)[1] &&
        RegexElement(ExactlyOne, Value, 'b') == parse(str2)[2] &&
        RegexElement(ExactlyOne, Value, 'c') == parse(str2)[3]
    end

    str3 = "a?bc"
    @test 3 == length(parse(str3))
    @test begin
        RegexElement(ZeroOrOne, Value, 'a') == parse(str3)[1] &&
        RegexElement(ExactlyOne, Value, 'b') == parse(str3)[2] &&
        RegexElement(ExactlyOne, Value, 'c') == parse(str3)[3]
    end
end

@testset "parser" begin
    re1 = parse("a")
    @test (true, 1) == test(re1, "a")

    re2 = parse("a?")
    @test (true, 1) == test(re2, "a")
    @test (true, 0) == test(re2, "")

    re3 = parse("a?bc")
    @test test(re3, "bc") == (true, 2)
    @test test(re3, "abc") == (true, 3)
end
