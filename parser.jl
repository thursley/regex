
import Base.copy

last(l::Array) = (length(l) == 0) ? nothing : l[length(l)]

@enum Quantifier ExactlyOne ZeroOrOne ZeroOrMore
@enum RegexType Wildcard Value Group Alternative

mutable struct RegexElement
    quantifier::Quantifier
    type::RegexType
    value::Any
end

mutable struct BackTrackState
    isbacktrackable::Bool
    state::RegexElement
    consumed::Array{Integer}
end

copy(el::RegexElement) = RegexElement(el.quantifier, el.type, el.value)

function parse(re::String)
    stack = []
    alternativeActive = false
    push!(stack, [])

    i = 1;
    while i <= length(re)
        next = re[i]

        if alternativeActive && next != ']'
            if '\\' === next
                if length(re) === i
                    throw(ErrorException("nothing to escape left"))
                end
                next = i + 1
            end
            push!(last(stack), next)
            i += 2

        elseif next == '.'
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

        elseif next == '['
            alternativeActive = true
            push!(stack, [])
            i += 1

        elseif next == ']'
            if length(stack) == 1
                throw(ErrorException("no alternatives to close"))
            end
            alternativeActive = false
            alternatives = pop!(stack)
            push!(last(stack), ExactlyOne, Alternative, alternatives)
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

function unshift!(a::Array, value::Any)
    pushfirst!(a, value)
    return length(a)
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
        match, consumed = test(state.value, SubString(string, index))
        return (match, match ? consumed : 0)

    elseif Alternative === state.type
        for value in state.value
            if value === string[index]
                return (true, 1)
            end
        end
        return (false, 0)
        
    else
        throw(ErrorException("unkown type"))
    end
end

function test(re::Array, string::AbstractString)
    states = copy(re)
    currentstate = shift!(states)
    index = 1
    backtrackstack::Array{BackTrackState} = []

    function backtrack()
        unshift!(states, currentstate)
        couldbacktrack = false

        while length(backtrackstack) > 0
            backtracked = pop!(backtrackstack)
            if backtracked.isbacktrackable
                if length(backtracked.consumed) === 0
                    # this state didnt made a difference, we have to unshift 
                    # it to continue with the state before.
                    unshift!(states, backtracked.state)
                    continue
                end
                # revert index
                index -= pop!(backtracked.consumed)
                # there could be more in consumed, so continue with this state
                push!(backtrackstack, backtracked)
                couldbacktrack = true
                break
            end

            unshift!(states, backtracked.state)
            foreach(c -> index -= c, backtracked.consumed)
            
            end

        if couldbacktrack
            currentstate = shift!(states)
        end

        return couldbacktrack
    end

    while currentstate !== nothing
        if ExactlyOne == currentstate.quantifier
            ismatch, consumed = matchesstring(currentstate, string, index)
            if !ismatch
                oldindex = index
                # try to backtrack and try again
                if !backtrack()
                    # not able to backtrack, we failed.
                    return (false, oldindex)
                end
                # we are in a new state, continue.
                continue
            end

            index += consumed
            push!(backtrackstack, BackTrackState(false, currentstate, [ consumed ]))
            currentstate = shift!(states)

        elseif ZeroOrOne == currentstate.quantifier
            ismatch, consumed = matchesstring(currentstate, string, index)
            index += consumed
            
            # only backtrackable, when consumed something.
            push!(backtrackstack, BackTrackState(ismatch, currentstate, [ consumed ]))

            currentstate = shift!(states)

        elseif ZeroOrMore == currentstate.quantifier
            backtrackstate = BackTrackState(
                true, currentstate, []
            )

            while true
                ismatch, consumed = matchesstring(currentstate, string, index)
                if !ismatch || consumed == 0
                    if length(backtrackstate.consumed) === 0
                        # we didn't consume anything
                        push!(backtrackstate.consumed, 0)
                        backtrackstate.isbacktrackable = false
                    end

                    push!(backtrackstack, backtrackstate)
                    break
                end

                push!(backtrackstate.consumed, consumed)
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