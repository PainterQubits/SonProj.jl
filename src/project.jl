const DEFAULT_VER = v"16.54"

# Some blocks don't need dimensional information.
(::Type{B})(u::DimensionsBlock) where {B} = B()

mutable struct SubdividerBlock <: Block  end
mutable struct FileOutBlock <: Block end
function Base.show(io::IO, b::FileOutBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet file out block")
end
mutable struct ComponentFileBlock <: Block end

mutable struct Project
    geometryproj::Bool
    version::String
    autodelete::Bool
    header::HeaderBlock
    dimensions::DimensionsBlock
    geometry::GeometryBlock
    frequency::FrequencyBlock
    control::ControlBlock
    optimization::OptimizationBlock
    variablesweep::ParameterSweepBlock
    parameter::ParameterBlock
    circuitelements::CircuitElementsBlock
    subdivider::SubdividerBlock
    fileout::FileOutBlock
    componentfile::ComponentFileBlock
    qsg::QSGBlock

    function Project()
        p = new()
        p.autodelete = false
        p.header = HeaderBlock()
        p.dimensions = DimensionsBlock()
        p.frequency = FrequencyBlock()
        p.control = ControlBlock()
        p.optimization = OptimizationBlock()
        p.variablesweep = ParameterSweepBlock()
        p.qsg = QSGBlock()
        return p
    end
end

root() = "├─"
leaf() = "│ "
lastroot() = "└─"
lastleaf() = "  "
function Base.show(io::IO, p::Project)
    println(io, "┌─Sonnet project:")
    println(io, "│   Geometry project: ", p.geometryproj)
    println(io, "│   Version:          ", p.version)
    println(io, "│   Auto-delete:      ", p.autodelete)

    blocks = Block[]
    for f in fieldnames(p)[4:end]
        isdefined(p, f) && push!(blocks, getfield(p, f))
    end
    for b in blocks[1:(end-1)]
        show(IOContext(io, :root=>root(), :leaf=>leaf()), b)
    end
    show(IOContext(io, :root=>lastroot(), :leaf=>lastleaf()), blocks[end])
end

function GeometryProject()
    p = Project()
    p.geometryproj = true
    p.geometry = GeometryBlock()
    return p
end

function NetlistProject()
    p = Project()
    p.geometryproj = false
    p.parameter = ParameterBlock()
    p.circuitelements = CircuitElementsBlock()
    return p
end

function Base.read(io::IO, ::Type{Project})
    b = Project()
    l = readline(io)
    if startswith(l, "FTYP")
        strs = split(l)
        b.geometryproj = ifelse(strs[2] == "SONPROJ", true, false)
    else
        error("project did not start with `FTYP` tag.")
    end

    l = readline(io)
    if startswith(l, "VER") # not required
        b.version = split(l)[2]
        l = readline(io)
    end
    if startswith(l, "HEADER")
        b.header = read(io, HeaderBlock)
    else
        error("`HEADER` block missing.")
    end

    l = readline(io)
    if startswith(l, "DIM")
        b.dimensions = read(io, DimensionsBlock)
    else
        error("`DIM` block missing.")
    end

    readblocks!(b, io, b.dimensions)
    verify(b)

    return b
end

function readblocks!(b::Project, io::IO, u::DimensionsBlock)
    while !eof(io)
        l = readline(io)
        for (str,field,T) in [("FREQ",    :frequency,       FrequencyBlock),
                              ("CONTROL", :control,         ControlBlock),
                              ("GEO",     :geometry,        GeometryBlock),
                              ("OPT",     :optimization,    OptimizationBlock),
                              ("VARSWP",  :variablesweep,   ParameterSweepBlock),
                              ("FILEOUT", :fileout,         FileOutBlock),
                              ("VAR",     :parameter,       ParameterBlock),
                              ("CKT",     :circuitelements, CircuitElementsBlock),
                              ("SUBDIV",  :subdivider,      SubdividerBlock),
                              ("QSG",     :qsg,             QSGBlock)]
            if startswith(l, str)
                verify(b, str)
                setfield!(b, field, read(io, T, u))
                @goto NEXTBLOCK
            end
        end
        error("unknown block: $l")
        @label NEXTBLOCK
    end
end

function verify(b::Project, blockstr)
    geoblocks = ("GEO", "SUBDIV", "QSG")
    netlistblocks = ("VAR", "CKT")
    if b.geometryproj && blockstr in netlistblocks
        error("did not expect $blockstr in a geometry project.")
    elseif !b.geometryproj && blockstr in geoblocks
        error("did not expect $blockstr in a netlist project.")
    end
end

function verify(b::Project)
    # TODO: make sure required blocks are present.
    # TODO: make sure NET=GEO in optimization block for geometry project
end

function Base.write(io::IO, b::Project)
    println(io, ifelse(b.geometryproj,
        "FTYP SONPROJ 16 ! Sonnet Project File",
        "FTYP SONNETPRJ 16 ! Sonnet Netlist Project File"))
    if isdefined(b, :version)
        println(io, "VER ", b.version)
    end

    for field in (:header,
                  :dimensions,
                  :frequency,
                  :control,
                  :geometry,
                  :optimization,
                  :variablesweep,
                  :parameter,
                  :circuitelements,
                  :subdivider,
                  :fileout,
                  :componentfile)
        if isdefined(b, field)
            write(io, getfield(b, field), b.dimensions)
        end
    end
    b.geometryproj && isdefined(b, :qsg) && write(io, b.qsg)
end

viewgeometry(p::String) = run(`$(xgeompath()) $p \&`)
viewresponse(p::String) = run(`$(emgraphpath()) $p \&`)
viewcurrents(p::String) = run(`$(emvupath()) $p \&`)
