
import Base.copy
import PrettyPrint.pprintln

last(l::Array) = (length(l) == 0) ? nothing : l[length(l)]

@enum Quantifier ExactlyOne ZeroOrOne ZeroOrMore
@enum RegexType Wildcard Value Group

mutable struct RegexElement
    quantifier::Quantifier
    type::RegexType
    value::Any
end

copy(el::RegexElement) = RegexElement(el.quantifier, el.type, el.value)

function parse(re::String)
    stack = []
    push!(stack, [])

    i = 1;
    while i <= length(re)
        next = re[i]
        if next == '.'
            push!(last(stack), RegexElement(ExactlyOne, Wildcard, '.'))
            i += 1

        elseif  next == '?'
            lastelem = last(last(stack))
            if lastelem === nothing
                throw(ErrorException("quantifier may not be first element in group"))
            end

            lastelem.quantifier = ZeroOrOne
            i += 1

        elseif next == '*'
            lastelem = last(last(stack))
            if lastelem === nothing
                throw(ErrorException("quantifier may not be first element in group"))
            end

            lastelem.quantifier = ZeroOrMore
            i += 1

        elseif next == '+'
            lastelem = last(last(stack))
            if lastelem === nothing
                throw(ErrorException("quantifier may not be first element in group"))
            end

            push!(last(stack), copy(lastelem))
            last(last(stack)).quantifier = ZeroOrMore
            i += 1

        elseif next == '('
            push!(stack, [])
            i += 1

        elseif next == ')'
            if length(stack) == 1
                throw(ErrorException("no group to close"))
            end

            group = pop!(stack)
            push!(last(stack), RegexElement(ExactlyOne, Group, group))
            i += 1

        elseif next == '\\'
            if i == length(re)
                # escaped char must follow
                throw(ErrorException("no character to escape"))
            end

            push!(last(stack), RegexElement(ExactlyOne, Value, re[i + 1]))
            i += 2

        else
            push!(last(stack), RegexElement(ExactlyOne, Value, re[i]))
            i += 1
        end
    end

    if length(stack) != 1
        throw(ErrorException("unclosed group"))
    end
    
    return stack[1]
end

function shift!(a::Array)
    if isempty(a)
        return nothing
    end
    return popfirst!(a)
end

function matchesstring(state::RegexElement, string::AbstractString, index::Integer)
    if index > length(string)
        return (false, 0)

    elseif state.type == Wildcard
        return (true, 1)

    elseif state.type == Value
        if string[index] == state.value
            return (true, 1)
        else
            return (false, 0)
        end

    elseif state.type == Group
        return test(state.value, SubString(string, index))

    else
        throw(ErrorException("unkown type"))
    end
end

function test(re::Array, string::AbstractString)
    states = copy(re)
    currentstate = shift!(states)
    index = 1

    while currentstate !== nothing
        if ExactlyOne == currentstate.quantifier
            ismatch, consumed = matchesstring(currentstate, string, index)
            if !ismatch
                return (false, index)
            end
            index += consumed
            currentstate = shift!(states)

        elseif ZeroOrOne == currentstate.quantifier
            ismatch, consumed = matchesstring(currentstate, string, index)
            index += consumed
            currentstate = shift!(states)

        elseif ZeroOrMore == currentstate.quantifier
            while true
                ismatch, consumed = matchesstring(currentstate, string, index)
                if !ismatch || consumed == 0
                    break
                end
                index += consumed
            end
            currentstate = shift!(states)
        
        else
            throw(ErrorException("unkown quantifier {currentstate.quantifier}"))
        end
    end

    return (true, index - 1)
end

re = parse("a?bc")
test(re, "abc")