module Callbacks

export After, Before, emit!

struct After{T}
    func::T
end

struct Before{T}
    func::T
end

emit!(prob, callback) = nothing

end
