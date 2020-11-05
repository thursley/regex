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

@testset "test_unshift" begin
    a = [1]
    @test 2 == unshift!(a, 2)
    @test 2 == a[1]
    @test 3 == unshift!(a, 18)
    @test begin
        18 == a[1] &&
        2 == a[2] &&
        1 == a[3] &&
        3 == length(a)
    end
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

    re4 = parse("a*b")
    @test (true, 2) == test(re4, "ab")
    re4 = parse("a*b")
    @test (true, 3) == test(re4, "aab")
    re4 = parse("a*b")
    @test (true, 9) == test(re4, "aaaaaaaab")
    re4 = parse("a*b")
    @test false == test(re4, "aaaaaaaa")[1]
    re4 = parse("a*b")
    @test false == test(re4, "aaaaaaaac")[1]
    
    re5 = parse("a*a")
    @test (true, 1) == test(re5, "a") 
    @test (true, 2) == test(re5, "aa")
    
    re6 = parse("a(bc)*bc")
    @test (true, 3) == test(re6, "abc")
    @test (true, 5) == test(re6, "abcbc")
    
    re7 = parse("a(bc)?bc")
    @test (true, 3) == test(re7, "abc")
    @test (true, 5) == test(re7, "abcbc")
    
    re8 = parse("a(bc)*b?c?")
    @test (true, 1) == test(re8, "a")
    @test (true, 2) == test(re8, "ab")
    @test (true, 2) == test(re8, "ac")
end

@testset "test_groups" begin
    re = parse("a(abc)+d")
    @test (true, 5) == test(re, "aabcd")
    @test (true, 8) == test(re, "aabcabcd")
    @test (false, 2) == test(re, "abcabcd")

    re2 = parse("a(bc(de)?)e")
    @test (true, 6) == test(re2, "abcdee")
    re2 = parse("a(bc(de)?)e")
    @test (true, 4) == test(re2, "abce")
    re2 = parse("a(bc(de)?)e")
    @test (false, 6) == test(re2, "abcde")
end
