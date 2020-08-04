abstract type CircuitElement end
function Base.show(io::IO, c::CircuitElement)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, c.nodes)
    for s in fieldnames(c)
        s == :nodes && continue
        println(io, leaf, string(s), ": ", getfield(c, s))
    end
end

mutable struct Resistor <: CircuitElement
    nodes::NTuple{2, Int}
    v::ElectricalResistance
end
function Base.write(io::IO, r::Resistor, u=DimensionsBlock())
    println(io, "RES ", r.nodes[1], " ",
        (r.nodes[2]==0 ? "" : string(r.nodes[2], " ")),
        "R=", ustrip(r.v |> u.resistance))
end

mutable struct Inductor <: CircuitElement
    nodes::NTuple{2, Int}
    v::Inductance
end
function Base.write(io::IO, r::Inductor, u=DimensionsBlock())
    println(io, "IND ", r.nodes[1], " ",
        (r.nodes[2]==0 ? "" : string(r.nodes[2], " ")),
        "L=", ustrip(r.v |> u.inductance))
end

mutable struct Capacitor <: CircuitElement
    nodes::NTuple{2, Int}
    v::Capacitance
end
function Base.write(io::IO, r::Capacitor, u=DimensionsBlock())
    println(io, "CAP ", r.nodes[1], " ",
        (r.nodes[2]==0 ? "" : string(r.nodes[2], " ")),
        "C=", ustrip(r.v |> u.capacitance))
end

mutable struct TransmissionLine <: CircuitElement
    nodes::NTuple{2, Int}
    z::ElectricalResistance
    l::Length
    f::Frequency
end
function Base.write(io::IO, r::TransmissionLine, u=DimensionsBlock())
    println(io, "TLIN ", r.nodes[1], " ", r.nodes[2],
        " Z=", ustrip(r.z |> u.resistance),
        " E=", ustrip(r.l |> u.length),
        " F=", ustrip(r.f |> u.frequency))
end

mutable struct PhysicalTransmissionLine <: CircuitElement
    nodes::NTuple{2, Int}
    z::ElectricalResistance
    l::Length
    k::Float64
    f::Frequency
    a::Attenuation
end
function Base.write(io::IO, r::PhysicalTransmissionLine, u=DimensionsBlock())
    println(io, "TLINP ", join(r.nodes, " "),
        " Z=", ustrip(r.z |> u.resistance),
        " L=", ustrip(r.l |> u.length),
        " K=", r.k,
        " F=", ustrip(r.f |> u.frequency),
        " A=", ustrip(r.a |> (dB_rp / u.length)))
end

mutable struct CoupledCoils <: CircuitElement
    nodes::NTuple{4, Int}
    l1::Inductance
    l2::Inductance
    m::Union{Missing, Inductance}
    k::Union{Missing, Float64}
end
function Base.write(io::IO, r::CoupledCoils, u=DimensionsBlock())
    ismissing(r.m) && ismissing(r.k) && error("both m and k are specified.")
    !ismissing(r.m) && !ismissing(r.k) && error("neither m nor k are specified.")
    print(io, "MUC ", join(r.nodes, " "),
        " L1=", ustrip(r.l1 |> u.inductance),
        " L2=", ustrip(r.l2 |> u.inductance))
    ismissing(r.m) ?
        println(io, " K=", r.k) :
        println(io, " M=", ustrip(r.m |> u.inductance))
end

abstract type SourceElement <: CircuitElement end
function Base.write(io::IO, r::SourceElement)
    if r isa VoltageControlledVoltageSource
        print(io, "VCVS ")
    elseif r isa VoltageControlledCurrentSource
        print(io, "VCCS ")
    elseif r isa CurrentControlledVoltageSource
        print(io, "CCVS ")
    else
        print(io, "CCCS ")
    end
    println(io, join(r.nodes, " "), " R1=", r.r1, " R2=", r.r2," GM=", r.gain)
end

mutable struct VoltageControlledCurrentSource <: SourceElement
    nodes::NTuple{4, Int}
    r1::ElectricalResistance
    r2::ElectricalResistance
    gain
end
mutable struct VoltageControlledVoltageSource <: CircuitElement
    nodes::NTuple{4, Int}
    r1::ElectricalResistance
    r2::ElectricalResistance
    gain
end
mutable struct CurrentControlledCurrentSource <: CircuitElement
    nodes::NTuple{4, Int}
    r1::ElectricalResistance
    r2::ElectricalResistance
    gain
end
mutable struct CurrentControlledVoltageSource <: CircuitElement
    nodes::NTuple{4, Int}
    r1::ElectricalResistance
    r2::ElectricalResistance
    gain
end

mutable struct TouchstoneFile <: CircuitElement
    nodes::Tuple{Vararg{Int}}
    gndnode::Int
    filename::String
end
function Base.show(io::IO, c::TouchstoneFile)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    print(io, root, c.nodes)
    c.gndnode != 0 && print(io, " (Gnd = $(c.gndnode))")
    println(io, ": ", c.filename)
end
function Base.write(io::IO, r::TouchstoneFile)
    print(io, "S", length(r.nodes), "P ")
    print(io, join(r.nodes, " "), " ")
    if r.gndnode != 0
        print(io, gndnode, " ")
    end
    println(io, filename)
end

mutable struct ProjectFile <: CircuitElement
    nodes::Tuple{Vararg{Int}}
    gndnode::Int
    sweepfromsubproj::Bool
    parameters::Dict{String, Any}
    dt::DateTime
    filename::String
end
function Base.show(io::IO, c::ProjectFile)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    print(io, root, c.nodes)
    c.gndnode != 0 && print(io, " (Gnd = $(c.gndnode))")
    println(io, ": ", c.filename)
    println(io, leaf, "Last modified: ", c.dt)
    println(io, leaf, "Use sweep from sub-project: ", c.sweepfromsubproj)
    println(io, leaf, "Parameters: ")
    for kv in c.parameters
        println(io, leaf, "  ", kv.first, " = ", kv.second)
    end
end
function Base.write(io::IO, r::ProjectFile)
    print(io, "PRJ ", join(r.nodes, " "), " ")
    if r.gndnode != 0
        print(io, r.gndnode, " ")
    end
    print(io, r.filename, " ")
    print(io, length(r.nodes), " ")
    print(io, ifelse(r.sweepfromsubproj, "1 ", "0 "))
    print(io, "DATE ", Dates.format(r.dt, "mm/dd/yyyy HH:MM:SS "))
    for p in r.parameters
        print(io, p[1], "=", p[2], " ")
    end
    println(io)
end

mutable struct NetworkPort
    z::ElectricalResistance
    l::Inductance
    c::Capacitance
end
function Base.show(io::IO, p::NetworkPort)
    leaf = get(io, :leaf, "")
    print(io, leaf, "Z = ", p.z, "; L = ", p.l, "; C = ", p.c)
end
function Base.write(io::IO, p::NetworkPort, u=DimensionsBlock())
    h = get(io, :header, "")
    z, l, c = p.z, p.l, p.c
    if h == "R"
        println(io, real(ustrip(z |> u.resistance)))
    elseif h == "TERM" || h == "Z"
        q = ustrip(z |> u.resistance)
        println(io, real(q), " ", imag(q))
    else
        q = ustrip(z |> u.resistance)
        println(io, real(q), " ", imag(q), " ",
            ustrip(l |> u.inductance), " ", ustrip(c |> u.capacitance))
    end
end

mutable struct Network <: CircuitElement
    nodes::Tuple{Vararg{Int}}
    name::String
    multiport::Bool
    ports::Tuple{Vararg{NetworkPort}}
end
function Base.show(io::IO, c::Network)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    print(io, root, c.nodes)
    println(io, ": ", c.name)
    println(io, leaf, "Port terminations: ")
    for p in c.ports
        println(IOContext(io, leaf=leaf*"  "), p)
    end
end
function Base.write(io::IO, c::Network, u=DimensionsBlock())
    print(io, "DEF", length(c.nodes), "P ", join(c.nodes, " "), " ")
    print(io, c.name, " ")
    header = if c.multiport
        # header is "TERM" or "FTERM"
        all(iszero(p.l) && iszero(p.c) for p in c.ports) ?
            "TERM" : "FTERM"
    else
        if all(iszero(p.l) && iszero(p.c) for p in c.ports)
            if all(isreal(p.z) for p in c.ports)
                "R"
            else
                "Z"
            end
        else
            "SPFTERM"
        end
    end
    write(io, header, " ")
    for p in c.ports
        write(IOContext(io, header=header), p, u)
    end
    println()
end

mutable struct CircuitElementsBlock <: Block
    r::Vector{Resistor}
    l::Vector{Inductor}
    c::Vector{Capacitor}
    tl::Vector{TransmissionLine}
    ptl::Vector{PhysicalTransmissionLine}
    cc::Vector{CoupledCoils}
    src::Vector{SourceElement}
    snp::Vector{TouchstoneFile}
    prj::Vector{ProjectFile}
    net::Vector{Network}
    function CircuitElementsBlock()
        return new(Resistor[], Inductor[], Capacitor[], TransmissionLine[],
            PhysicalTransmissionLine[], CoupledCoils[], SourceElement[],
            TouchstoneFile[], ProjectFile[], Network[])
    end
end
function Base.show(io::IO, b::CircuitElementsBlock)
    r = get(io, :root, "")
    l = get(io, :leaf, "")
    println(io, r, "Sonnet circuit elements block:")
    isempty(b.r) ? nothing : println(io, l, "  Resistors:")
    for (i,p) in enumerate(b.r)
        i == length(b.tl) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.l) ? nothing : println(io, l, "  Inductors:")
    for (i,p) in enumerate(b.l)
        i == length(b.l) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.c) ? nothing : println(io, l, "  Capacitors:")
    for (i,p) in enumerate(b.c)
        i == length(b.c) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.tl) ? nothing : println(io, l, "  Transmission lines:")
    for (i,p) in enumerate(b.tl)
        i == length(b.tl) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.ptl) ? nothing : println(io, l, "  Physical transmission lines:")
    for (i,p) in enumerate(b.ptl)
        i == length(b.ptl) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.cc) ? nothing : println(io, l, "  Coupled coils:")
    for (i,p) in enumerate(b.cc)
        i == length(b.cc) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.src) ? nothing : println(io, l, "  Source element:")
    for (i,p) in enumerate(b.src)
        i == length(b.src) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.snp) ? nothing : println(io, l, "  Touchstone files:")
    for (i,p) in enumerate(b.snp)
        i == length(b.snp) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.prj) ? nothing : println(io, l, "  Sonnet project files:")
    for (i,p) in enumerate(b.prj)
        i == length(b.prj) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
    isempty(b.net) ? nothing : println(io, l, "  Network elements:")
    for (i,p) in enumerate(b.net)
        i == length(b.net) ?
            show(IOContext(io,
                root=l*"  "*lastroot(),
                leaf=l*"  "*lastleaf()), p) :
            show(IOContext(io,
                root=l*"  "*root(),
                leaf=l*"  "*leaf()), p)
    end
end

function process1(b::CircuitElementsBlock, io::IO, u::DimensionsBlock)
    l = sonreadline(io)
    if startswith(l, "END CKT")
        return true
    elseif startswith(l, "VCVS")
        strs = parsplit(l)
        nodes = (parse.(Int, strs[2:5])...)
        r1 = parse(Float64, strs[6][4:end]) * u.resistance
        r2 = parse(Float64, strs[7][4:end]) * u.resistance
        gm = Parse(Float64, strs[8][4:end])
        push!(b.src, VoltageControlledVoltageSource(nodes, r1, r2, gm))
    elseif startswith(l, "VCCS")
        strs = parsplit(l)
        nodes = (parse.(Int, strs[2:5])...)
        r1 = parse(Float64, strs[6][4:end]) * u.resistance
        r2 = parse(Float64, strs[7][4:end]) * u.resistance
        gm = Parse(Float64, strs[8][4:end])
        push!(b.src, VoltageControlledCurrentSource(nodes, r1, r2, gm))
    elseif startswith(l, "CCVS")
        strs = parsplit(l)
        nodes = (parse.(Int, strs[2:5])...)
        r1 = parse(Float64, strs[6][4:end]) * u.resistance
        r2 = parse(Float64, strs[7][4:end]) * u.resistance
        gm = Parse(Float64, strs[8][4:end])
        push!(b.src, CurrentControlledVoltageSource(nodes, r1, r2, gm))
    elseif startswith(l, "CCCS")
        strs = parsplit(l)
        nodes = (parse.(Int, strs[2:5])...)
        r1 = parse(Float64, strs[6][4:end]) * u.resistance
        r2 = parse(Float64, strs[7][4:end]) * u.resistance
        gm = Parse(Float64, strs[8][4:end])
        push!(b.src, CurrentControlledCurrentSource(nodes, r1, r2, gm))
    elseif startswith(l, "MUC")
        strs = parsplit(l)
        nodes = (parse.(Int, strs[2:5])...)
        l1 = parse(Float64, strs[6][4:end]) * u.inductance
        l2 = parse(Float64, strs[7][4:end]) * u.inductance
        if strs[8][1] == 'M'
            push!(b.cc, CoupledCoils(nodes, l1, l2,
                parse(Float64, strs[8][3:end]) * u.inductance, missing))
        else
            push!(b.cc, CoupledCoils(nodes, l1, l2,
                missing, parse(Float64, strs[8][3:end])))
        end
    elseif startswith(l, "RES")
        strs = parsplit(l)
        n1 = parse(Int, strs[2])
        n2 = get(tryparse(Int, strs[3]), 0)
        r = parse(Float64, last(strs)[3:end]) * u.resistance
        push!(b.r, Resistor((n1,n2), r))
    elseif startswith(l, "IND")
        strs = parsplit(l)
        n1 = parse(Int, strs[2])
        n2 = get(tryparse(Int, strs[3]), 0)
        r = parse(Float64, last(strs)[3:end]) * u.inductance
        push!(b.l, Inductor((n1,n2), r))
    elseif startswith(l, "CAP")
        strs = parsplit(l)
        n1 = parse(Int, strs[2])
        n2 = get(tryparse(Int, strs[3]), 0)
        r = parse(Float64, last(strs)[3:end]) * u.capacitance
        push!(b.c, Capacitor((n1,n2), r))
    elseif startswith(l, "TLINP")
        strs = parsplit(l)
        n1 = parse(Int, strs[2])
        n2 = parse(Int, strs[3])
        z = parse(Float64, strs[4][3:end]) * u.resistance
        l = parse(Float64, strs[5][3:end]) * u.length
        k = parse(Float64, strs[6][3:end])
        f = parse(Float64, strs[7][3:end]) * u.frequency
        a = parse(Float64, strs[8][3:end]) * dB_rp / u.length
        push!(b.ptl, PhysicalTransmissionLine((n1,n2),z,l,k,f,a))
    elseif startswith(l, "TLIN")
        strs = parsplit(l)
        n1 = parse(Int, strs[2])
        n2 = parse(Int, strs[3])
        z = parse(Float64, strs[4][3:end]) * u.resistance
        l = parse(Float64, strs[5][3:end]) * u.length
        f = parse(Float64, strs[6][3:end]) * u.frequency
        push!(b.tl, TransmissionLine((n1,n2),z,l,f))
    elseif startswith(l, "PRJ")
        strs = parsplit(l)
        i = 2
        while !isnull(tryparse(Int, strs[i]))
            i += 1
        end
        numprt = parse(Int, strs[i+1])
        nodes = (parse.(Int, strs[2:(2+numprt-1)])...)
        if i == 2+numprt
            gndnode = 0
        else
            gndnode = parse(Int, strs[2+numprt])
        end
        filename = strs[i]
        sweepfromsubproj = parse(Int, strs[i+2]) == 1
        dt = DateTime(string(strs[i+4], " ", strs[i+5]),
            dateformat"mm/dd/yyyy HH:MM:SS")
        d = Dict{String, Any}()
        for s in strs[(i+6):end]
            kv = split(s, "=")
            d[kv[1]] = get(tryparse(Float64, kv[2]), kv[2])
        end
        push!(b.prj, ProjectFile(nodes, gndnode, sweepfromsubproj, d, dt, filename))
    elseif startswith(l, "DEF")
        np = parse(Int, l[4])
        strs = split(l)
        nodes = (parse.(Int, strs[2:(2+np-1)])...)
        name = strs[2+np]
        portheader = strs[2+np+1]
        local mp, p
        if portheader == "R"
            mp = false
            p = (NetworkPort(parse(Float64, strs[2+np+2])*u.resistance,
                    0.0*u.inductance,
                    0.0*u.capacitance),)
        elseif portheader == "Z"
            mp = false
            p = (NetworkPort(
                    Complex(parse(Float64, strs[2+np+2]),
                        parse(Float64, strs[2+np+3]))*u.resistance,
                    0.0*u.inductance,
                    0.0*u.capacitance),)
        elseif portheader == "TERM"
            mp = true
            p = ((NetworkPort(
                    Complex(parse(Float64, strs[i]),
                        parse(Float64, strs[i+1]))*u.resistance,
                    0.0*u.inductance,
                    0.0*u.capacitance) for i in (2+np+2):2:length(strs))...)
        elseif portheader == "FTERM"
            mp = true
            p = ((NetworkPort(
                    Complex(parse(Float64, strs[i]),
                        parse(Float64, strs[i+1]))*u.resistance,
                    parse(Float64, strs[i+2])*u.inductance,
                    parse(Float64, strs[i+3])*u.capacitance) for i in (2+np+2):4:length(strs))...)
        elseif portheader == "SPFTERM"
            mp = false
            p = let i = 2+np+2
                (NetworkPort(
                    Complex(parse(Float64, strs[i]),
                        parse(Float64, strs[i+1]))*u.resistance,
                    parse(Float64, strs[i+2])*u.inductance,
                    parse(Float64, strs[i+3])*u.capacitance),)
            end
        else
            error("unexpected port terminations.")
        end
        push!(b.net, Network(nodes, name, mp, p))
    elseif startswith(l, "S")
        np = parse(Int, l[2])
        strs = split(l)
        nodes = (parse.(Int, strs[2:(np+1)])...)
        gndnode = get(tryparse(strs[np+2]), 0)
        push!(b.snp, TouchstoneFile(nodes, gndnode, strs[end]))
    else
        error("unexpected line in circuit elements block: ", l)
    end
    return false
end

function Base.write(io::IO, b::CircuitElementsBlock, u=DimensionsBlock())
    println(io, "CKT")
    for r in b.r
        write(io, r, u)
    end
    for l in b.l
        write(io, l, u)
    end
    for c in b.c
        write(io, c, u)
    end
    for tl in b.tl
        write(io, tl, u)
    end
    for ptl in b.ptl
        write(io, ptl, u)
    end
    for cc in b.cc
        write(io, cc, u)
    end
    for snp in b.snp
        write(io, snp)
    end
    for prj in b.prj
        write(io, prj)
    end
    for net in b.net
        write(io, net, u)
    end
    println(io, "END CKT")
end
