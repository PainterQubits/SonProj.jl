mutable struct ParameterSweep
    sweep::Sweep
    parameters::Dict{String, Tuple{Bool, Sweep}}
end
function Base.show(io::IO, b::ParameterSweep)
    leaf = get(io, :leaf, "")
    print(io, leaf, "  ")
    show(io, b.sweep)
    println(io)
    for kv in b.parameters
        print(io, leaf, "    ")
        print(io, "Variable ", kv[1], ifelse(kv[2][1], "", " (unused)"), ": ")
        print(io, kv[2][2])
        println(io)
    end
end

mutable struct ParameterSweepBlock <: Block
    sweeps::Vector{ParameterSweep}
    ParameterSweepBlock() = new(ParameterSweep[])
end
function Base.show(io::IO, b::ParameterSweepBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet parameter sweep block:")
    for s in b.sweeps
        show(io, s)
    end
end

function process1(b::ParameterSweepBlock, io::IO, u::DimensionsBlock)
    l = sonreadline(io)
    if startswith(l, "END VARSWP")
        return true
    end
    sweep = parsesweep(l)
    parameters = Dict{String, Tuple{Bool, Sweep}}()
    l = sonreadline(io)
    while !startswith(l, "END")
        strs = split(l)
        name = strs[2]
        used = strs[3] != "N"
        vsweep = if strs[3] == "N"
            StepRangeSweep(sonparse.(Float64, strs[4:end]).*u.frequency...)
        elseif strs[3] == "Y"
            StepRangeSweep(sonparse.(Float64, strs[4:end]).*u.frequency...)
        elseif strs[3] == "YN"
            n = ifelse(length(strs) >= 6, sonparse(Int, strs[6]), ())
            start = sonparse(Float64, strs[4])*u.frequency
            stop = ifelse(length(strs) >= 5,
                sonparse(Float64, strs[5])*u.frequency, ())
            LinSpaceSweep(start, stop..., n...)
        elseif strs[3] == "YC"
            CornerSweep(sonparse.(Float64, strs[4:end]).*u.frequency...)
        elseif strs[3] == "YS"
            SensitivitySweep(sonparse.(Float64, strs[4:end]).*u.frequency...)
        elseif strs[3] == "YE"
            n = ifelse(length(strs) >= 6, sonparse(Int, strs[6]), ())
            start = sonparse(Float64, strs[4])*u.frequency
            stop = ifelse(length(strs) >= 5,
                sonparse(Float64, strs[5])*u.frequency, ())
            ExponentialSweep(start, stop..., n...)
        else
            error("unexpected sweep type.")
        end
        parameters[name] = (used, vsweep)
        l = sonreadline(io)
    end
    push!(b.sweeps, ParameterSweep(sweep, parameters))
    return false
end

function Base.write(io::IO, b::ParameterSweepBlock, u=DimensionsBlock())
    println(io, "VARSWP")
    for s in b.sweeps
        write(io, s.sweep, u)
        for kv in s.parameters
            k,v = kv[1], kv[2]
            used, sw = v[1], v[2]
            tag = if sw isa StepRangeSweep
                "Y"
            elseif sw isa LinSpaceSweep
                "YN"
            elseif sw isa CornerSweep
                "YC"
            elseif sw isa SensitivitySweep
                "YS"
            elseif sw isa ExponentialSweep
                "YE"
            else
                error("unexpected sweep type: $sw")
            end
            if !used
                println(io, "VAR ", k, " N ",
                    join(_fmt.((sw.start, sw.stop, sw.step), u), " "))
            else
                println(io, "VAR ", k, " ", tag, " ",
                    join(_fmt.(((getfield(sw,c) for c in fieldnames(sw))...), u), " "))
            end
        end
        println(io, "END")
    end
    println(io, "END VARSWP")
end

_fmt(x::Int, u) = x == -1 ? "UNDEF" : string(x)
_fmt(x, u) = isnan(x)? "UNDEF" : string(ustrip(x |> u.frequency))
