module Toolboxes

#--- Dependencies

import ..Lenny: close!

#--- Exports

# Exported types
export AbstractToolbox

#--- Base toolbox type

abstract type AbstractToolbox{T <: Number} end

close!(prob, toolbox::AbstractToolbox) = toolbox

end  # module
