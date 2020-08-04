struct ParameterBlock <: Block
    parameters::Dict{String, Float64}
    ParameterBlock() = new(Dict{String, Float64}())
end
function Base.show(io::IO, b::ParameterBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet parameter block:")
    for p in b.parameters
        print(io, leaf, "  ")
        println(io, p.first, " = ", p.second)
    end
end

function process1(b::ParameterBlock, io::IO)
    l = sonreadline(io)
    if startswith(l, "END VAR")
        return true
    else
        kv = split(replace(l, " ", ""), "=")
        b.parameters[kv[1]] = parse(Float64, kv[2])
        return false
    end
end

function Base.write(io::IO, b::ParameterBlock, u=DimensionsBlock())
    println(io, "VAR")
    for p in b.parameters
        println(io, p[1], " = ", ustrip(p[2]))
    end
    println(io, "END VAR")
end
