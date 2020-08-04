
function process1 end
process1(b::Block, io::IO, u::DimensionsBlock) = process1(b, io)

function Base.read(io::IO, T::Type{<:Block}, u::DimensionsBlock=DimensionsBlock())
    b = T(u)
    while !eof(io)
        # do something with the processed line
        isdone = process1(b, io, u)
        isdone && break
    end
    return b
end

"""
    sonreadline(io)
Returns one effective line from a Sonnet project file, which may be several
actual lines if a continuation character is encountered.
"""
function sonreadline(io)
    continuedline = ""
    while !eof(io)
        line = strip(readline(io))

        # skip empty lines
        isempty(line) && continue

        # technically '!<' is allowed but not sure when that happens
        line[1] == '!' && continue # comment line

        line = join((continuedline, line), "")
        c = search(line, '&')
        if c > 0    # continuation character found
            continuedline = line[1:(c-1)]
        else
            return line
        end
    end
    throw(EOFError())
end

"""
    quotesplit(s::AbstractString)
Splits by spaces, but not inside pairs of quotation marks. Removes quotation
marks from the resulting substrings.
"""
function quotesplit(s::AbstractString)
    quot = split(s, '"', keep=true)
    l = length(quot)
    funcs = Iterators.cycle((split,identity))
    return vcat(
        (func(str) for (func, str) in Iterators.take(zip(funcs, quot), l))...)
end

"""
    parsplit(s::AbstractString)
Splits by spaces, but removes spaces adjacent to `=` signs prior to splitting.
Intended to make it easy to parse keyword arguments.
"""
function parsplit(s::AbstractString)
    return split(replace(replace(s, " =", "="), "= ", "="))
end

"""
    sonparse(x,y)
Same as `parse` but will parse "UNDEF" as `NaN` when parsing for `Float64`, and
"UNDEF" as `-1` when parsing for `Int`.
"""
sonparse(x,y) = parse(x,y)
function sonparse(::Type{Int}, x::AbstractString)
    return if lowercase(x) == "undef"
        -1
    else
        parse(Int, x)
    end
end
function sonparse(::Type{Float64}, x::AbstractString)
    return if lowercase(x) == "undef"
        NaN
    else
        parse(Float64, x)
    end
end

import Unitful: NoUnits
function sonvarparse(::Type{T}, s::AbstractString, u=NoUnits) where T<:Real
    v = tryparse(T, s)
    return if isnull(v)
        Variable{dimension(u)}(replace(s, "\"", ""))
    else
        get(v) * u
    end
end

function sondeclparse(::Type{T}, s::AbstractString, u=NoUnits) where T<:Real
    v = tryparse(T, s)
    return if isnull(v)
        replace(s, "\"", "")
    else
        get(v) * u
    end
end
