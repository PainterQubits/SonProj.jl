mutable struct HeaderBlock <: Block
    license::String
    lastsaved::DateTime
    createdinfo::String
    savedinfo::String
    mediumsaved::DateTime
    highsaved::DateTime

    HeaderBlock() = new()
    HeaderBlock(a,b,c,d,e,f) = new(a,b,c,d,e,f)
end

function Base.show(io::IO, b::HeaderBlock)
    root = get(io, :root, "")
    leaf = get(io, :leaf, "")
    println(io, root, "Sonnet header block:")
    println(io, leaf, "  License:    ", b.license)
    println(io, leaf, "  Last saved: ", b.lastsaved)
    println(io, leaf, "  ", b.createdinfo)
    println(io, leaf, "  ", b.savedinfo)
    println(io, leaf, "  Last saved (medium priority): ", b.mediumsaved)
    println(io, leaf, "  Last saved (high priority):   ", b.highsaved)
end

function Base.read(io::IO, T::Type{HeaderBlock})
    b = T()
    while !eof(io)
        # do something with the processed line
        isdone = process1(b, io)
        isdone && break
    end
    return b
end

function process1(b::HeaderBlock, io::IO)
    l = sonreadline(io)
    isdone = false
    if startswith(l, "LIC")
        b.license = l
    elseif startswith(l, "DAT")
        b.lastsaved = DateTime(l[5:end], dateformat"mm/dd/yyyy HH:MM:SS")
    elseif startswith(l, "BUILT_BY_CREATED")
        b.createdinfo = l
    elseif startswith(l, "BUILT_BY_SAVED")
        b.savedinfo = l
    elseif startswith(l, "MDATE")
        b.mediumsaved = DateTime(l[7:end], dateformat"mm/dd/yyyy HH:MM:SS")
    elseif startswith(l, "HDATE")
        b.highsaved = DateTime(l[7:end], dateformat"mm/dd/yyyy HH:MM:SS")
    elseif startswith(l, "END")
        isdone = true
    else
        error("unexpected line in header block: ", l)
    end
    return isdone
end

function Base.write(io::IO, header::HeaderBlock)
    println(io, "HEADER")
    if !isempty(header.license)
        println(io, header.license)
    end
    println(io, "DAT ", Dates.format(header.lastsaved, "mm/dd/yyyy HH:MM:SS"))
    if !isempty(header.createdinfo)
        println(io, header.createdinfo)
    else
        println(io, "BUILT_BY_CREATED SonProj.jl") #TODO: LibGit2.commit_id
    end

    println(io, "BUILT_BY_SAVED SonProj.jl") #TODO: LibGit2.commit_id

    if isdefined(header, :mediumsaved)
        println(io, "MDATE ", Dates.format(header.mediumsaved, "mm/dd/yyyy HH:MM:SS"))
    end
    if isdefined(header, :highsaved)
        println(io, "HDATE ", Dates.format(header.highsaved, "mm/dd/yyyy HH:MM:SS"))
    end

    println(io, "END HEADER")
end
