# 2016 Andrew J. Keller
__precompile__(true)
module SonProj
using StringEncodings
using Unitful
using Missings

abstract type Block end

include("header.jl")
include("dimensions.jl")

include(joinpath("utils", "parser.jl"))

include(joinpath("geometry", "geometry.jl"))
include("frequency.jl")
include("control.jl")
include("optimization.jl")
include("varswp.jl")
include("qsg.jl")
include("parameter.jl")
include("circuitelements.jl")
include("project.jl")

# since we defined some new units/dimensions...
const localunits = Unitful.basefactors
function __init__()
    merge!(Unitful.basefactors, localunits)
end
end
