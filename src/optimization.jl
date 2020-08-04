# TODO units, probably
mutable struct OptimizationVariable
    name::String
    used::Bool
    min::Float64
    max::Float64
    granularity::Float64
end
function OptimizationVariable(name::AbstractString, used::AbstractString,
        min::AbstractString, max::AbstractString, granularity::AbstractString)
    a,b,c = tryparse.(Float64, (min, max, granularity))
    OptimizationVariable(name, used == "Y",
        (x->isnull(x) ? NaN : get(x)).((a,b,c))...)
end

function Base.write(io::IO, v::OptimizationVariable)
    println(io, "VAR ", v.name, " ", ifelse(v.used, 'Y', 'N'), " ",
        ifelse(isnan(v.min), "UNDEF", v.min), " ",
        ifelse(isnan(v.max), "UNDEF", v.max), " ",
        ifelse(isnan(v.granularity), "UNDEF", v.granularity))
end

mutable struct Optimization
    sweep::Sweep
    net::String
    restype
    respar
    rel
    tartype
    tarvalue
    weight
end

# TODO units, probably
function Base.write(io::IO, v::Optimization)
    write(io, v.sweep)
    print(io, "NET=", ifelse(v.net == "GEO", "GEO", "\""*v.net*"\""), " ")
    print(io, v.restype, '[', v.respar, "] ")
    println(io, v.rel, " ", v.tartype, "=", v.tarvalue, " ", v.weight)
end

mutable struct OptimizationBlock <: Block
    maxiter::Int
    vars::Vector{OptimizationVariable}
    opts::Vector{Optimization}

    function OptimizationBlock()
        b = new()
        b.maxiter=100
        b.vars = OptimizationVariable[]
        b.opts = Optimization[]
        return b
    end
end

function Base.show(io::IO, b::OptimizationBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet optimization block:")
    for v in b.vars
        print(io, leaf, "  ")
        println(io, v)
    end
    for v in b.opts
        print(io, leaf, "  ")
        println(io, v)
    end
end

function processvar(b::OptimizationBlock, io)
    l = sonreadline(io)
    if startswith(l, "END")
        return false
    else
        push!(b.vars, OptimizationVariable(split(l)[2:end]...))
        return true
    end
end

function processgoal(b::OptimizationBlock, l1, l2)
    goal = split(l2)
    net = strip(goal[1][5:end], '"')
    w = search(goal[2], '[')
    restype = goal[2][1:(w-1)]
    respar = goal[2][(w+1):(end-1)]
    rel = goal[3]
    tartype, tarvalue = split(goal[4], "=")
    weight = goal[5]

    push!(b.opts, Optimization(parsesweep(l1),
        net, restype, respar, rel, tartype, tarvalue, weight))
end

function process1(b::OptimizationBlock, io::IO)
    l = sonreadline(io)
    if startswith(l, "END")
        return true
    elseif startswith(l, "VARS")
        while processvar(b, io) end
    elseif startswith(l, "MAX")
        b.maxiter = parse(Int, split(l)[2])
    elseif startswith(l, "SWEEP")
        processgoal(b, l, sonreadline(io))
    elseif startswith(l, "ESWEEP")
        processgoal(b, l, sonreadline(io))
    elseif startswith(l, "LSWEEP")
        processgoal(b, l, sonreadline(io))
    elseif startswith(l, "STEP")
        processgoal(b, l, sonreadline(io))
    elseif startswith(l, "ABS_ENTRY")
        processgoal(b, l, sonreadline(io))
    elseif startswith(l, "DC_FREQ")
        processgoal(b, l, sonreadline(io))
    else
        error("unexpected line in optimization block: ", l)
    end
    return false
end

function Base.write(io::IO, b::OptimizationBlock)
    println(io, "OPT")
    println(io, "MAX ", b.maxiter)
    println(io, "VARS")
    for v in b.vars
        write(io, v)
    end
    println(io, "END")
    for o in b.opts
        write(io, o)
    end
    println(io, "END OPT")
end
