# functions for trait evolution on network
# Claudia & Paul Bastide: November 2015

###############################################################################
###############################################################################
## Function to traverse the network in the pre-order, updating a matrix
###############################################################################
###############################################################################

# Matrix with rows and/or columns in topological order of the net.
"""
`MatrixTopologicalOrder`

Matrix associated to an [`HybridNetwork`](@ref) sorted in topological order.

The following functions and extractors can be applied to it: [`tipLabels`](@ref), `obj[:Tips]`, `obj[:InternalNodes]`, `obj[:TipsNodes]` (see documentation for function [`getindex(::MatrixTopologicalOrder, ::Symbol)`](@ref)).

Functions [`sharedPathMatrix`](@ref) and [`simulate`](@ref) return objects of this type.

The `MatrixTopologicalOrder` object has fields: `V`, `nodeNumbersTopOrder`, `internalNodeNumbers`, `tipNumbers`, `tipNames`, `indexation`.
Type in "?MatrixTopologicalOrder.field" to get documentation on a specific field.
"""
struct MatrixTopologicalOrder
    "V: the matrix per se"
    V::Matrix # Matrix in itself
    "nodeNumbersTopOrder: vector of nodes numbers in the topological order, used for the matrix"
    nodeNumbersTopOrder::Vector{Int} # Vector of nodes numbers for ordering of the matrix
    "internalNodeNumbers: vector of internal nodes number, in the original net order"
    internalNodeNumbers::Vector{Int} # Internal nodes numbers (original net order)
    "tipNumbers: vector of tips numbers, in the origial net order"
    tipNumbers::Vector{Int} # Tips numbers (original net order)
    "tipNames: vector of tips names, in the original net order"
    tipNames::Vector # Tips Names (original net order)
    """
    indexation: a string giving the type of matrix `V`:
    -"r": rows only are indexed by the nodes of the network
    -"c": columns only are indexed by the nodes of the network
    -"b": both rows and columns are indexed by the nodes of the network
    """
    indexation::AbstractString # Are rows ("r"), columns ("c") or both ("b") indexed by nodes numbers in the matrix ?
end

function Base.show(io::IO, obj::MatrixTopologicalOrder)
    println(io, "$(typeof(obj)):\n$(obj.V)")
end

function tipLabels(obj::MatrixTopologicalOrder)
    return obj.tipNames
end

# This function takes an init and update funtions as arguments
# It does the recursion using these functions on a preordered network.
function recursionPreOrder(net::HybridNetwork,
                           checkPreorder=true::Bool,
                           init=identity::Function,
                           updateRoot=identity::Function,
                           updateTree=identity::Function,
                           updateHybrid=identity::Function,
                           indexation="b"::AbstractString,
                           params...)
    net.isRooted || error("net needs to be rooted to get matrix of shared path lengths")
    if(checkPreorder)
        preorder!(net)
    end
    M = recursionPreOrder(net.nodes_changed, init, updateRoot, updateTree, updateHybrid, params)
    # Find numbers of internal nodes
    nNodes = [n.number for n in net.node]
    nleaf = [n.number for n in net.leaf]
    deleteat!(nNodes, indexin(nleaf, nNodes))
    MatrixTopologicalOrder(M, [n.number for n in net.nodes_changed], nNodes, nleaf, [n.name for n in net.leaf], indexation)
end

function recursionPreOrder(nodes::Vector{Node},
                           init::Function,
                           updateRoot::Function,
                           updateTree::Function,
                           updateHybrid::Function,
                           params)
    n = length(nodes)
    M = init(nodes, params)
    for i in 1:n #sorted list of nodes
        updatePreOrder!(i, nodes, M, updateRoot, updateTree, updateHybrid, params)
    end
    return M
end

# Update on the network
# Takes three function as arguments : updateRoot, updateTree, updateHybrid
function updatePreOrder!(i::Int,
                         nodes::Vector{Node},
                         V::Matrix, updateRoot::Function,
                         updateTree::Function,
                         updateHybrid::Function,
                         params)
    parent = getParents(nodes[i]) #array of nodes (empty, size 1 or 2)
    if(isempty(parent)) #nodes[i] is root
        updateRoot(V, i, params)
    elseif(length(parent) == 1) #nodes[i] is tree
        parentIndex = getIndex(parent[1],nodes)
        edge = getConnectingEdge(nodes[i],parent[1])
        updateTree(V, i, parentIndex, edge, params)
    elseif(length(parent) == 2) #nodes[i] is hybrid
        parentIndex1 = getIndex(parent[1],nodes)
        parentIndex2 = getIndex(parent[2],nodes)
        edge1 = getConnectingEdge(nodes[i],parent[1])
        edge2 = getConnectingEdge(nodes[i],parent[2])
        edge1.hybrid || error("connecting edge between node $(nodes[i].number) and $(parent[1].number) should be a hybrid egde")
        edge2.hybrid || error("connecting edge between node $(nodes[i].number) and $(parent[2].number) should be a hybrid egde")
        updateHybrid(V, i, parentIndex1, parentIndex2, edge1, edge2, params)
    end
end

## Same, but in post order (tips to root)
function recursionPostOrder(net::HybridNetwork,
                            checkPreorder=true::Bool,
                            init=identity::Function,
                            updateTip=identity::Function,
                            updateNode=identity::Function,
                            indexation="b"::AbstractString,
                            params...)
    net.isRooted || error("net needs to be rooted to get matrix of shared path lengths")
    if(checkPreorder)
        preorder!(net)
    end
    M = recursionPostOrder(net.nodes_changed, init, updateTip, updateNode, params)
    # Find numbers of internal nodes
    nNodes = [n.number for n in net.node]
    nleaf = [n.number for n in net.leaf]
    deleteat!(nNodes, indexin(nleaf, nNodes))
    MatrixTopologicalOrder(M, [n.number for n in net.nodes_changed], nNodes, nleaf, [n.name for n in net.leaf], indexation)
end

function recursionPostOrder(nodes::Vector{Node},
                            init::Function,
                            updateTip::Function,
                            updateNode::Function,
                            params)
    n = length(nodes)
    M = init(nodes, params)
    for i in n:-1:1 #sorted list of nodes
        updatePostOrder!(i, nodes, M, updateTip, updateNode, params)
    end
    return M
end

function updatePostOrder!(i::Int,
                          nodes::Vector{Node},
                          V::Matrix,
                          updateTip::Function,
                          updateNode::Function,
                          params)
    children = getChildren(nodes[i]) #array of nodes (empty, size 1 or 2)
    if(isempty(children)) #nodes[i] is a tip
        updateTip(V, i, params)
    else
        childrenIndex = [getIndex(n, nodes) for n in children]
        edges = [getConnectingEdge(nodes[i], c) for c in children]
        updateNode(V, i, childrenIndex, edges, params)
    end
end

# Extract the right part of a matrix in topological order
# Tips : submatrix corresponding to tips
# InternalNodes : submatrix corresponding to internal nodes
# TipsNodes : submatrix nTips x nNodes of interactions
# !! Extract sub-matrices in the original net nodes numbers !!
# function Base.getindex(obj::MatrixTopologicalOrder, d::Symbol)
#   if d == :Tips # Extract rows and/or columns corresponding to the tips
#       mask = indexin(obj.tipNumbers, obj.nodeNumbersTopOrder)
#       obj.indexation == "b" && return obj.V[mask, mask] # both columns and rows are indexed by nodes
#       obj.indexation == "c" && return obj.V[:, mask] # Only the columns
#       obj.indexation == "r" && return obj.V[mask, :] # Only the rows
#   end
#   if d == :InternalNodes # Idem, for internal nodes
#       mask = indexin(obj.internalNodeNumbers, obj.nodeNumbersTopOrder)
#       obj.indexation == "b" && return obj.V[mask, mask]
#       obj.indexation == "c" && return obj.V[:, mask]
#       obj.indexation == "r" && return obj.V[mask, :]
#   end
#   if d == :TipsNodes
#       maskNodes = indexin(obj.internalNodeNumbers, obj.nodeNumbersTopOrder)
#       maskTips = indexin(obj.tipNumbers, obj.nodeNumbersTopOrder,)
#       obj.indexation == "b" && return obj.V[maskTips, maskNodes]
#       obj.indexation == "c" && error("Both rows and columns must be net
#       ordered to take the submatrix tips vs internal nodes.")
#       obj.indexation == "r" && error("Both rows and columns must be net
#       ordered to take the submatrix tips vs internal nodes.")
#   end
#   d == :All && return obj.V
# end

# If some tips are missing, treat them as "internal nodes"
"""
`getindex(obj, d,[ indTips, msng])`

Getting submatrices of an object of type [`MatrixTopologicalOrder`](@ref).

# Arguments
* `obj::MatrixTopologicalOrder`: the matrix from which to extract.
* `d::Symbol`: a symbol precising which sub-matrix to extract. Can be:
  * `:Tips` columns and/or rows corresponding to the tips
  * `:InternalNodes` columns and/or rows corresponding to the internal nodes
  * `:TipsNodes` columns corresponding to internal nodes, and row to tips (works only is indexation="b")
* `indTips::Vector{Int}`: optional argument precising a specific order for the tips (internal use).
* `msng::BitArray{1}`: optional argument precising the missing tips (internal use).

"""
function Base.getindex(obj::MatrixTopologicalOrder,
                       d::Symbol,
                       indTips=collect(1:length(obj.tipNumbers))::Vector{Int},
                       msng=trues(length(obj.tipNumbers))::BitArray{1})
    if d == :Tips # Extract rows and/or columns corresponding to the tips with data
        maskTips = indexin(obj.tipNumbers, obj.nodeNumbersTopOrder)
        maskTips = maskTips[indTips]
        maskTips = maskTips[msng]
        obj.indexation == "b" && return obj.V[maskTips, maskTips] # both columns and rows are indexed by nodes
        obj.indexation == "c" && return obj.V[:, maskTips] # Only the columns
        obj.indexation == "r" && return obj.V[maskTips, :] # Only the rows
    end
    if d == :InternalNodes # Idem, for internal nodes
        maskNodes = indexin(obj.internalNodeNumbers, obj.nodeNumbersTopOrder)
        maskTips = indexin(obj.tipNumbers, obj.nodeNumbersTopOrder)
        maskTips = maskTips[indTips]
        maskNodes = [maskNodes; maskTips[.!msng]]
        obj.indexation == "b" && return obj.V[maskNodes, maskNodes]
        obj.indexation == "c" && return obj.V[:, maskNodes]
        obj.indexation == "r" && return obj.V[maskNodes, :]
    end
    if d == :TipsNodes
        maskNodes = indexin(obj.internalNodeNumbers, obj.nodeNumbersTopOrder)
        maskTips = indexin(obj.tipNumbers, obj.nodeNumbersTopOrder)
        maskTips = maskTips[indTips]
        maskNodes = [maskNodes; maskTips[.!msng]]
        maskTips = maskTips[msng]
        obj.indexation == "b" && return obj.V[maskTips, maskNodes]
        obj.indexation == "c" && error("""Both rows and columns must be net
                                       ordered to take the submatrix tips vs internal nodes.""")
        obj.indexation == "r" && error("""Both rows and columns must be net
                                       ordered to take the submatrix tips vs internal nodes.""")
    end
    d == :All && return obj.V
end

###############################################################################
###############################################################################
## Functions to compute the variance-covariance between Node and its parents
###############################################################################
###############################################################################
"""
`sharedPathMatrix(net::HybridNetwork; checkPreorder=true::Bool)`

This function computes the shared path matrix between all the nodes of a
network. It assumes that the network is in the pre-order. If checkPreorder is
true (default), then it runs function `preoder` on the network beforehand.

Returns an object of type [`MatrixTopologicalOrder`](@ref).

"""
function sharedPathMatrix(net::HybridNetwork;
                          checkPreorder=true::Bool)
    recursionPreOrder(net,
                      checkPreorder,
                      initsharedPathMatrix,
                      updateRootSharedPathMatrix!,
                      updateTreeSharedPathMatrix!,
                      updateHybridSharedPathMatrix!,
                      "b")
end

function updateRootSharedPathMatrix!(V::Matrix, i::Int, params)
    return
end


function updateTreeSharedPathMatrix!(V::Matrix,
                                     i::Int,
                                     parentIndex::Int,
                                     edge::Edge,
                                     params)
    for j in 1:(i-1)
        V[i,j] = V[j,parentIndex]
        V[j,i] = V[j,parentIndex]
    end
    V[i,i] = V[parentIndex,parentIndex] + edge.length
end

function updateHybridSharedPathMatrix!(V::Matrix,
                                       i::Int,
                                       parentIndex1::Int,
                                       parentIndex2::Int,
                                       edge1::Edge,
                                       edge2::Edge,
                                       params)
    for j in 1:(i-1)
        V[i,j] = V[j,parentIndex1]*edge1.gamma + V[j,parentIndex2]*edge2.gamma
        V[j,i] = V[i,j]
    end
    V[i,i] = edge1.gamma*edge1.gamma*(V[parentIndex1,parentIndex1] + edge1.length) + edge2.gamma*edge2.gamma*(V[parentIndex2,parentIndex2] + edge2.length) + 2*edge1.gamma*edge2.gamma*V[parentIndex1,parentIndex2]
end

function initsharedPathMatrix(nodes::Vector{Node}, params)
    n = length(nodes)
    return(zeros(Float64,n,n))
end

###############################################################################
###############################################################################
## Functions to compute the network matrix
###############################################################################
###############################################################################
"""
`incidenceMatrix(net::HybridNetwork; checkPreorder=true::Bool)`

Returns an object of type [`MatrixTopologicalOrder`](@ref).

"""
function incidenceMatrix(net::HybridNetwork;
                         checkPreorder=true::Bool)
    recursionPostOrder(net,
                       checkPreorder,
                       initIncidenceMatrix,
                       updateTipIncidenceMatrix!,
                       updateNodeIncidenceMatrix!,
                       "r")
end

function updateTipIncidenceMatrix!(V::Matrix,
                                   i::Int,
                                   params)
    return
end

function updateNodeIncidenceMatrix!(V::Matrix,
                                    i::Int,
                                    childrenIndex::Vector{Int},
                                    edges::Vector{Edge},
                                    params)
    for j in 1:length(edges)
        V[:,i] += edges[j].gamma*V[:,childrenIndex[j]]
    end
end

function initIncidenceMatrix(nodes::Vector{Node}, params)
    n = length(nodes)
    return(eye(Float64,n,n))
end

###############################################################################
## Function to get the regressor out of a shift
###############################################################################

function regressorShift(node::Vector{Node},
                        net::HybridNetwork; checkPreorder=true::Bool)
    T = incidenceMatrix(net; checkPreorder=checkPreorder)
    regressorShift(node, net, T)
end

function regressorShift(node::Vector{Node},
                        net::HybridNetwork,
                        T::MatrixTopologicalOrder)
    ## Get the incidence matrix for tips
    T_t = T[:Tips]
    ## Get the indices of the columns to keep
    ind = zeros(Int, length(node))
    for i in 1:length(node)
        !node[i].hybrid || error("Shifts on hybrid edges are not allowed")
        ind[i] = getIndex(node[i], net.nodes_changed)
    end
    df = DataFrame(T_t[:, ind])
    function tmp_fun(x::Int)
        if x<0
            return(Symbol("shift_m$(-x)"))
        else
            return(Symbol("shift_$(x)"))
        end
    end
    names!(df, [tmp_fun(n.number) for n in node])
    df[:tipNames]=T.tipNames
    return(df)
end

function regressorShift(edge::Vector{Edge},
                        net::HybridNetwork; checkPreorder=true::Bool)
    childs = [getChild(ee) for ee in edge]
    return(regressorShift(childs, net; checkPreorder=checkPreorder))
end

regressorShift(edge::Edge, net::HybridNetwork; checkPreorder=true::Bool) = regressorShift([edge], net; checkPreorder=checkPreorder)
regressorShift(node::Node, net::HybridNetwork; checkPreorder=true::Bool) = regressorShift([node], net; checkPreorder=checkPreorder)

function regressorHybrid(net::HybridNetwork; checkPreorder=true::Bool)
    childs = [getChildren(nn)[1] for nn in net.hybrid]
    dfr = regressorShift(childs, net; checkPreorder=checkPreorder)
    dfr[:sum] = vec(sum(Array(dfr[:,find(names(dfr) .!= :tipNames)]), 2))
    return(dfr)
end

###############################################################################
###############################################################################
## Types for params process
###############################################################################
###############################################################################

# Abstract type of all the (future) types (BM, OU, ...)
abstract type ParamsProcess end

# Type for shifts
"""
`ShiftNet`

Shifts associated to an [`HybridNetwork`](@ref) sorted in topological order.

"""
type ShiftNet
    shift::Vector{Real}
end

# Default
ShiftNet(net::HybridNetwork) = ShiftNet(zeros(length(net.node)))

function ShiftNet{T <: Real}(node::Vector{Node}, value::Vector{T},
                             net::HybridNetwork; checkPreorder=true::Bool)
    if length(node) != length(value)
        error("The vector of nodes/edges and of values must be of the same length.")
    end
    if(checkPreorder)
        preorder!(net)
    end
    obj = ShiftNet(net)
    for i in 1:length(node)
        !node[i].hybrid || error("Shifts on hybrid edges are not allowed")
        ind = getIndex(node[i], net.nodes_changed)
        obj.shift[ind] = value[i]
    end
    return(obj)
end

# Construct from edges and values
function ShiftNet{T <: Real}(edge::Vector{Edge}, value::Vector{T},
                             net::HybridNetwork; checkPreorder=true::Bool)
    childs = [getChild(ee) for ee in edge]
    return(ShiftNet(childs, value, net; checkPreorder=checkPreorder))
end

ShiftNet(edge::Edge, value::Real, net::HybridNetwork; checkPreorder=true::Bool) = ShiftNet([edge], [value], net; checkPreorder=checkPreorder)
ShiftNet(node::Node, value::Real, net::HybridNetwork; checkPreorder=true::Bool) = ShiftNet([node], [value], net; checkPreorder=checkPreorder)

function ShiftHybrid{T <: Real}(value::Vector{T},
                                net::HybridNetwork; checkPreorder=true::Bool)
    if length(net.hybrid) != length(value)
        error("You must provide as many values as the number of hybrid nodes.")
    end
    childs = [getChildren(nn)[1] for nn in net.hybrid]
    return(ShiftNet(childs, value, net; checkPreorder=checkPreorder))
end

function getEdgeNumber(shift::ShiftNet)
    collect(1:length(shift.shift))[shift.shift .!= 0]
end
function getValue(shift::ShiftNet)
    shift.shift[shift.shift .!= 0]
end

function shiftTable(shift::ShiftNet)
    CoefTable(hcat(getEdgeNumber(shift), getValue(shift)),
              ["Edge Number", "Shift Value"],
              fill("", length(getValue(shift))))
end

function Base.show(io::IO, obj::ShiftNet)
    println(io, "$(typeof(obj)):\n",
            shiftTable(obj))
end

function Base.:*(sh1::ShiftNet, sh2::ShiftNet)
    length(sh1.shift) == length(sh2.shift) || error("Shifts to be concatenated must have the same length")
    shiftNew = zeros(length(sh1.shift))
    for i in 1:length(sh1.shift)
        if sh1.shift[i] == 0
            shiftNew[i] = sh2.shift[i]
        elseif sh2.shift[i] == 0
            shiftNew[i] = sh1.shift[i]
        elseif sh1.shift[i] == sh2.shift[i]
            shiftNew[i] = sh1.shift[i]
        else
            error("The two shifts vectors you provided affect the same edges, so I cannot choose which one you want.")
        end
    end
    return(ShiftNet(shiftNew))
end


"""
`ParamsBM <: ParamsProcess`

Type for a BM process on a network. Fields are `mu` (expectation),
`sigma2` (variance), `randomRoot` (whether the root is random, default to `false`),
and `varRoot` (if the root is random, the variance of the root, defalut to `NaN`).

"""
# BM type
mutable struct ParamsBM <: ParamsProcess
    mu::Real # Ancestral value or mean
    sigma2::Real # variance
    randomRoot::Bool # Root is random ? default false
    varRoot::Real # root variance. Default NaN
    shift::Nullable{ShiftNet} # shifts
end
# Constructor
ParamsBM(mu::Real, sigma2::Real) = ParamsBM(mu, sigma2, false, NaN, Nullable{ShiftNet}()) # default values
ParamsBM(mu::Real, sigma2::Real, net::HybridNetwork) = ParamsBM(mu, sigma2, false, NaN, ShiftNet(net)) # default values
ParamsBM(mu::Real, sigma2::Real, shift::ShiftNet) = ParamsBM(mu, sigma2, false, NaN, shift) # default values

function anyShift(params::ParamsBM)
    if isnull(params.shift) return(false) end
    for v in params.shift.value.shift
        if v != 0 return(true) end
    end
    return(false)
end

function Base.show(io::IO, obj::ParamsBM)
    disp =  "$(typeof(obj)):\n"
    pt = paramstable(obj)
    if obj.randomRoot
        disp = disp * "Parameters of a BM with random root:\n" * pt
    else
        disp = disp * "Parameters of a BM with fixed root:\n" * pt
    end
    println(io, disp)
end

function paramstable(obj::ParamsBM)
    disp = "mu: $(obj.mu)\nSigma2: $(obj.sigma2)"
    if obj.randomRoot
        disp = disp * "\nvarRoot: $(obj.varRoot)"
    end
    if anyShift(obj)
        disp = disp * "\n\nThere are $(length(getValue(obj.shift.value))) shifts on the network:\n"
        disp = disp * "$(shiftTable(obj.shift.value))"
    end
    return(disp)
end


###############################################################################
###############################################################################
## Simulation Function
###############################################################################
###############################################################################

"""
`TraitSimulation`

Result of a trait simulation on an [`HybridNetwork`](@ref) with function [`simulate`](@ref).

The following functions and extractors can be applied to it: [`tipLabels`](@ref), `obj[:Tips]`, `obj[:InternalNodes]` (see documentation for function [`getindex(::TraitSimulation, ::Symbol)`](@ref)).

The `TraitSimulation` object has fields: `M`, `params`, `model`.
"""
struct TraitSimulation
    M::MatrixTopologicalOrder
    params::ParamsProcess
    model::AbstractString
end

function Base.show(io::IO, obj::TraitSimulation)
    disp = "$(typeof(obj)):\n"
    disp = disp * "Trait simulation results on a network with $(length(obj.M.tipNames)) tips, using a $(obj.model) model, with parameters:\n"
    disp = disp * paramstable(obj.params)
    println(io, disp)
end

"""
`tipLabels(obj::TraitSimulation)`
returns a vector of taxon names (at the leaves) for a simulated object.
"""
function tipLabels(obj::TraitSimulation)
    return tipLabels(obj.M)
end


"""
`simulate(net::HybridNetwork, params::ParamsProcess, checkPreorder=true::Bool)`

Simualte some traits on `net` using the parameters `params`. For now, only
parameters of type [`ParamsBM`](@ref) (Brownian Motion) are accepted.

Assumes that the network is in the pre-order. If `checkPreorder=true` (default),
then it runs function `preoder` on the network beforehand.

Returns an object of type [`TraitSimulation`](@ref).

# Examples
```jldoctest
julia> phy = readTopology(joinpath(Pkg.dir("PhyloNetworks"), "examples", "carnivores_tree.txt"));

julia> par = ParamsBM(1, 0.1) # BM with expectation 1 and variance 0.1.
PhyloNetworks.ParamsBM:
Parameters of a BM with fixed root:
mu: 1
Sigma2: 0.1

julia> srand(17920921); # Seed for reproducibility

julia> sim = simulate(phy, par) # Simulate on the tree.
PhyloNetworks.TraitSimulation:
Trait simulation results on a network with 16 tips, using a BM model, with parameters:
mu: 1
Sigma2: 0.1

julia> traits = sim[:Tips] # Extract simulated values at the tips.
16-element Array{Float64,1}:
  2.17618
  1.03308
  3.04898
  3.03796
  2.1897
  4.03159
  4.64773
 -0.877285
  4.62512
 -0.511167
  1.35604
 -0.103112
 -2.08847
  2.63991
  2.80512
  3.19109

```
"""
# Uses recursion on the network.
# Takes params of type ParamsProcess as an entry
# Returns a matrix with two lines:
# - line one = expectations at all the nodes
# - line two = simulated values at all the nodes
# The nodes are ordered as given by topological sorting
function simulate(net::HybridNetwork,
                  params::ParamsProcess,
                  checkPreorder=true::Bool)
    if isa(params, ParamsBM)
        model = "BM"
    else
        error("The 'simulate' function only works for a BM process (for now).")
    end
    !isnull(params.shift) || (params.shift = ShiftNet(net))
    M = recursionPreOrder(net,
                          checkPreorder,
                          initSimulateBM,
                          updateRootSimulateBM!,
                          updateTreeSimulateBM!,
                          updateHybridSimulateBM!,
                          "c",
                          params)
    TraitSimulation(M, params, model)
end

# Initialization of the structure
function initSimulateBM(nodes::Vector{Node}, params::Tuple{ParamsBM})
    return(zeros(2, length(nodes)))
end

# Initialization of the root
function updateRootSimulateBM!(M::Matrix, i::Int, params::Tuple{ParamsBM})
    params = params[1]
    if (params.randomRoot)
        M[1, i] = params.mu # expectation
        M[2, i] = params.mu + sqrt(params.varRoot) * randn() # random value
    else
        M[1, i] = params.mu # expectation
        M[2, i] = params.mu # random value (root fixed)
    end
end

# Going down to a tree node
function updateTreeSimulateBM!(M::Matrix,
                               i::Int,
                               parentIndex::Int,
                               edge::Edge,
                               params::Tuple{ParamsBM})
    params = params[1]
    M[1, i] = M[1, parentIndex] + params.shift.value.shift[i] # expectation
    M[2, i] = M[2, parentIndex] + params.shift.value.shift[i] + sqrt(params.sigma2 * edge.length) * randn() # random value
end

# Going down to an hybrid node
function updateHybridSimulateBM!(M::Matrix,
                                 i::Int,
                                 parentIndex1::Int,
                                 parentIndex2::Int,
                                 edge1::Edge,
                                 edge2::Edge,
                                 params::Tuple{ParamsBM})
    params = params[1]
    M[1, i] =  edge1.gamma * M[1, parentIndex1] + edge2.gamma * M[1, parentIndex2] # expectation
    M[2, i] =  edge1.gamma * (M[2, parentIndex1] + sqrt(params.sigma2 * edge1.length) * randn()) + edge2.gamma * (M[2, parentIndex2] + sqrt(params.sigma2 * edge2.length) * randn()) # random value
end


# function updateSimulateBM!(i::Int, nodes::Vector{Node}, M::Matrix, params::Tuple{ParamsBM})
#     params = params[1]
#     parent = getParents(nodes[i]) #array of nodes (empty, size 1 or 2)
#     if(isempty(parent)) #nodes[i] is root
#         if (params.randomRoot)
#       M[1, i] = params.mu # expectation
#       M[2, i] = params.mu + sqrt(params.varRoot) * randn() # random value
#   else
#       M[1, i] = params.mu # expectation
#       M[2, i] = params.mu # random value (root fixed)
#   end
#
#     elseif(length(parent) == 1) #nodes[i] is tree
#         parentIndex = getIndex(parent[1],nodes)
#   l = getConnectingEdge(nodes[i],parent[1]).length
#   M[1, i] = params.mu  # expectation
#   M[2, i] = M[2, parentIndex] + sqrt(params.sigma2 * l) * randn() # random value
#
#     elseif(length(parent) == 2) #nodes[i] is hybrid
#         parentIndex1 = getIndex(parent[1],nodes)
#         parentIndex2 = getIndex(parent[2],nodes)
#         edge1 = getConnectingEdge(nodes[i],parent[1])
#         edge2 = getConnectingEdge(nodes[i],parent[2])
#         edge1.hybrid || error("connecting edge between node $(nodes[i].number) and $(parent[1].number) should be a hybrid egde")
#         edge2.hybrid || error("connecting edge between node $(nodes[i].number) and $(parent[2].number) should be a hybrid egde")
#   M[1, i] = params.mu  # expectation
#   M[2, i] =  edge1.gamma * (M[2, parentIndex1] + sqrt(params.sigma2 * edge1.length) * randn()) + edge2.gamma * (M[2, parentIndex2] + sqrt(params.sigma2 * edge2.length) * randn()) # random value
#     end
# end

# Extract the vector of simulated values at the tips
"""
`getindex(obj, d)`

Getting submatrices of an object of type [`TraitSimulation`](@ref).

# Arguments
* `obj::TraitSimulation`: the matrix from which to extract.
* `d::Symbol`: a symbol precising which sub-matrix to extract. Can be:
  * `:Tips` columns and/or rows corresponding to the tips
  * `:InternalNodes` columns and/or rows corresponding to the internal nodes
"""
function Base.getindex(obj::TraitSimulation, d::Symbol, w=:Sim::Symbol)
     if w == :Exp
        return(getindex(obj.M, d)[1, :])
     end
    getindex(obj.M, d)[2, :]
end

# function extractSimulateTips(sim::Matrix, net::HybridNetwork)
#   mask = getTipsIndexes(net)
#   return(squeeze(sim[2, mask], 1))
# end

###############################################################################
###############################################################################
## Functions for Phylgenetic Network regression
###############################################################################
###############################################################################

# New type for phyloNetwork regression
"""
`PhyloNetworkLinearModel<:LinPredModel`

Regression object for a phylogenetic regression. Result of fitting function [`phyloNetworklm`](@ref).
Dominated by the `LinPredModel` class, from package `GLM`.

The following StatsBase functions can be applied to it:
`coef`, `nobs`, `vcov`, `stderr`, `confint`, `coeftable`, `dof_residual`, `dof`, `deviance`,
`residuals`, `model_response`, `predict`, `loglikelihood`, `nulldeviance`, `nullloglikelihood`,
`r2`, `adjr2`, `aic`, `aicc`, `bic`.

The following DataFrame functions can also be applied to it:
`ModelFrame`, `ModelMatrix`, `Formula`.

Estimated variance and mean of the BM process used can be retrieved with
functions [`sigma2_estim`](@ref) and [`mu_estim`](@ref).

If a Pagel's lambda model is fitted, the parameter can be retrieved with function
[`lambda_estim`](@ref).

An ancestral state reconstruction can be performed from this fitted object using function:
[`ancestralStateReconstruction`](@ref).

The `PhyloNetworkLinearModel` object has fields: `lm`, `V`, `Vy`, `RL`, `Y`, `X`, `logdetVy`, `ind`, `msng`, `model`, `lambda`.
Type in "?PhyloNetworkLinearModel.field" to get help on a specific field.
"""
mutable struct PhyloNetworkLinearModel <: LinPredModel
    "lm: a GLM.LinearModel object, fitted on the cholesky-tranformend problem"
    lm::GLM.LinearModel # result of a lm on a matrix
    "V: a MatrixTopologicalOrder object of the network-induced correlations"
    V::MatrixTopologicalOrder
    "Vy: the sub matrix corresponding to the tips and actually used for the correction"
    Vy::Matrix
    "RL: a LowerTriangular matrix, Cholesky transform of Vy=RL*RL'"
    RL::LowerTriangular
    "Y: the vector of data"
    Y::Vector
    "X: the matrix of regressors"
    X::Matrix
    "logdetVy: the log-determinent of Vy"
    logdetVy::Real
    "ind: vector matching the tips of the network against the names of the dataframe provided. 0 if the match could not be performed."
    ind::Vector{Int}
    "msng: vector indicating which of the tips are missing"
    msng::BitArray{1} # Which tips are not missing
    "model: the model used for the fit"
    model::AbstractString
    "If applicable, value of lambda (default to 1)."
    lambda::Real
end

PhyloNetworkLinearModel(lm_fit, V, Vy, RL, Y, X, logdetVy, ind, msng, model) = PhyloNetworkLinearModel(lm_fit, V, Vy, RL, Y, X, logdetVy, ind, msng, model, 1.0)

# Function for lm with net residuals
function phyloNetworklm(X::Matrix,
                        Y::Vector,
                        net::HybridNetwork;
                        msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                        model="BM"::AbstractString,
                        ind=[0]::Vector{Int},
                        startingValue=0.5::Real,
                        fixedValue=Nullable{Real}()::Nullable{Real})
    ## Choose Model
    if (model == "BM")
        # Geting variance covariance
        V = sharedPathMatrix(net)
        # Fit
        return phyloNetworklm_BM(X, Y, V;
                                 msng=msng, ind=ind)
    end
    if (model == "lambda")
        # Geting variance covariance
        V = sharedPathMatrix(net)
        # Get gammas and heights
        gammas = getGammas(net)
        times = getHeights(net)
        # Fit
        return phyloNetworklm_lambda(X, Y, V, gammas, times;
                                     msng=msng, ind=ind,
                                     startingValue=startingValue, fixedValue=fixedValue)
    end
    if (model == "scalingHybrid")
        # Get gammas
        preorder!(net)
        gammas = getGammas(net)
        # Fit
        return phyloNetworklm_scalingHybrid(X, Y, net, gammas;
                                            msng=msng, ind=ind,
                                            startingValue=startingValue, fixedValue=fixedValue)
    end
end

###############################################################################
## Fit BM

function phyloNetworklm_BM(X::Matrix,
                           Y::Vector,
                           V::MatrixTopologicalOrder;
                           msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                           ind=[0]::Vector{Int},
                           model="BM"::AbstractString,
                           lambda=1.0::Real)
    # Extract tips matrix
    Vy = V[:Tips]
    # Re-order if necessary
    if (ind != [0]) Vy = Vy[ind, ind] end
    # Keep only not missing values
    Vy = Vy[msng, msng]
    # Cholesky decomposition
    R = cholfact(Vy)
    RL = R[:L]
    # Fit
    PhyloNetworkLinearModel(lm(RL\X, RL\Y), V, Vy, RL, Y, X, logdet(Vy), ind, msng, model, lambda)
end

###############################################################################
## Fit Pagel's Lambda

# Get major gammas
function getGammas(net::HybridNetwork)
    isHybrid = [n.hybrid for n in net.nodes_changed]
    gammas = ones(size(isHybrid))
    for i in 1:size(isHybrid, 1)
        if isHybrid[i]
            majorHybrid = [n.hybrid & n.isMajor for n in net.nodes_changed[i].edge]
            gammas[i] = net.nodes_changed[i].edge[majorHybrid][1].gamma
        end
    end
    return gammas
end

function setGammas!(net::HybridNetwork, gammas::Vector)
    isHybrid = [n.hybrid for n in net.nodes_changed]
    for i in 1:size(isHybrid, 1)
        if isHybrid[i]
            majorHybrid = [n.hybrid & n.isMajor for n in net.nodes_changed[i].edge]
            minorHybrid = [n.hybrid & !n.isMajor for n in net.nodes_changed[i].edge]
            net.nodes_changed[i].edge[majorHybrid][1].gamma = gammas[i]
            if any(minorHybrid) # case where gamma = 0.5 exactly
                net.nodes_changed[i].edge[minorHybrid][1].gamma = 1 - gammas[i]
            else
                net.nodes_changed[i].edge[majorHybrid][2].gamma = 1 - gammas[i]
            end
            net.nodes_changed[i].edge[minorHybrid][1].gamma = 1 - gammas[i]
        end
    end
    return nothing
end

function getHeights(net::HybridNetwork)
    gammas = getGammas(net)
    setGammas!(net, ones(net.numNodes))
    V = sharedPathMatrix(net)
    setGammas!(net, gammas)
    return(diag(V[:All]))
end

function maxLambda(times::Vector, V::MatrixTopologicalOrder)
    maskTips = indexin(V.tipNumbers, V.nodeNumbersTopOrder)
    maskNodes = indexin(V.internalNodeNumbers, V.nodeNumbersTopOrder)
    return maximum(times[maskTips]) / maximum(times[maskNodes])
end

function transform_matrix_lambda!{T <: AbstractFloat}(V::MatrixTopologicalOrder, lam::T,
                                                      gammas::Vector, times::Vector)
    for i in 1:size(V.V, 1)
        for j in 1:size(V.V, 2)
            V.V[i,j] *= lam
        end
    end
    maskTips = indexin(V.tipNumbers, V.nodeNumbersTopOrder)
    for i in maskTips
        V.V[i, i] += (1-lam) * (gammas[i]^2 + (1-gammas[i])^2) * times[i]
    end
    #   V_diag = diagm(diag(V.V))
    #   V.V = lam * V.V + (1 - lam) * V_diag
end

function logLik_lam{T <: AbstractFloat}(lam::T,
                                        X::Matrix,
                                        Y::Vector,
                                        V::MatrixTopologicalOrder,
                                        gammas::Vector,
                                        times::Vector;
                                        msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                                        ind=[0]::Vector{Int})
    # Transform V according to lambda
    transform_matrix_lambda!(V, lam, gammas, times)
    # Fit and take likelihood
    fit_lam = phyloNetworklm_BM(X, Y, V; msng=msng, ind=ind)
    res = - loglikelihood(fit_lam)
    # Go back to original V
    transform_matrix_lambda!(V, 1/lam, gammas, times)
    return res
end

# Code for optim taken from PhyloNetworks.jl/src/optimization.jl, lines 276 - 331
const fAbsTr = 1e-10
const fRelTr = 1e-10
const xAbsTr = 1e-10
const xRelTr = 1e-10

function phyloNetworklm_lambda(X::Matrix,
                               Y::Vector,
                               V::MatrixTopologicalOrder,
                               gammas::Vector,
                               times::Vector;
                               msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                               ind=[0]::Vector{Int},
                               ftolRel=fRelTr::AbstractFloat,
                               xtolRel=xRelTr::AbstractFloat,
                               ftolAbs=fAbsTr::AbstractFloat,
                               xtolAbs=xAbsTr::AbstractFloat,
                               startingValue=0.5::Real,
                               fixedValue=Nullable{Real}()::Nullable{Real})
    if isnull(fixedValue)
        # Find Best lambda using optimize from package NLopt
        opt = NLopt.Opt(:LN_BOBYQA, 1)
        NLopt.ftol_rel!(opt, ftolRel) # relative criterion
        NLopt.ftol_abs!(opt, ftolAbs) # absolute critetion
        NLopt.xtol_rel!(opt, xtolRel) # criterion on parameter value changes
        NLopt.xtol_abs!(opt, xtolAbs) # criterion on parameter value changes
        NLopt.maxeval!(opt, 1000) # max number of iterations
        NLopt.lower_bounds!(opt, 1e-100) # Lower bound
        # Upper Bound
        up = maxLambda(times, V)
        NLopt.upper_bounds!(opt, up-up/1000)
        count = 0
        function fun(x::Vector{Float64}, g::Vector{Float64})
            x = convert(AbstractFloat, x[1])
            res = logLik_lam(x, X, Y, V, gammas, times; msng=msng, ind=ind)
            count =+ 1
            #println("f_$count: $(round(res,5)), x: $(x)")
            return res
        end
        NLopt.min_objective!(opt, fun)
        fmin, xmin, ret = NLopt.optimize(opt, [startingValue])
        # Best value dans result
        res_lam = xmin[1]
    else
        res_lam = fixedValue
    end
    transform_matrix_lambda!(V, res_lam, gammas, times)
    res = phyloNetworklm_BM(X, Y, V; msng=msng, ind=ind, model="lambda", lambda=res_lam)
#    res.lambda = res_lam
#    res.model = "lambda"
    return res
end

###############################################################################
## Fit scaling hybrid

function matrix_scalingHybrid{T <: AbstractFloat}(net::HybridNetwork, lam::T,
                                                  gammas::Vector)
    setGammas!(net, 1-lam*(1-gammas))
    V = sharedPathMatrix(net)
    setGammas!(net, gammas)
    return V
end

function logLik_lam_hyb{T <: AbstractFloat}(lam::T,
                                            X::Matrix,
                                            Y::Vector,
                                            net::HybridNetwork,
                                            gammas::Vector;
                                            msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                                            ind=[0]::Vector{Int})
    # Transform V according to lambda
    V = matrix_scalingHybrid(net, lam, gammas)
    # Fit and take likelihood
    fit_lam = phyloNetworklm_BM(X, Y, V; msng=msng, ind=ind)
    return -loglikelihood(fit_lam)
end

function phyloNetworklm_scalingHybrid(X::Matrix,
                                      Y::Vector,
                                      net::HybridNetwork,
                                      gammas::Vector;
                                      msng=trues(length(Y))::BitArray{1}, # Which tips are not missing ?
                                      ind=[0]::Vector{Int},
                                      ftolRel=fRelTr::AbstractFloat,
                                      xtolRel=xRelTr::AbstractFloat,
                                      ftolAbs=fAbsTr::AbstractFloat,
                                      xtolAbs=xAbsTr::AbstractFloat,
                                      startingValue=0.5::Real,
                                      fixedValue=Nullable{Real}()::Nullable{Real})
    if isnull(fixedValue)
        # Find Best lambda using optimize from package NLopt
        opt = NLopt.Opt(:LN_BOBYQA, 1)
        NLopt.ftol_rel!(opt, ftolRel) # relative criterion
        NLopt.ftol_abs!(opt, ftolAbs) # absolute critetion
        NLopt.xtol_rel!(opt, xtolRel) # criterion on parameter value changes
        NLopt.xtol_abs!(opt, xtolAbs) # criterion on parameter value changes
        NLopt.maxeval!(opt, 1000) # max number of iterations
        #NLopt.lower_bounds!(opt, 1e-100) # Lower bound
        #NLopt.upper_bounds!(opt, 1.0)
        count = 0
        function fun(x::Vector{Float64}, g::Vector{Float64})
            x = convert(AbstractFloat, x[1])
            res = logLik_lam_hyb(x, X, Y, net, gammas; msng=msng, ind=ind)
            #count =+ 1
            #println("f_$count: $(round(res,5)), x: $(x)")
            return res
        end
        NLopt.min_objective!(opt, fun)
        fmin, xmin, ret = NLopt.optimize(opt, [startingValue])
        # Best value dans result
        res_lam = xmin[1]
    else
        res_lam = fixedValue
    end
    V = matrix_scalingHybrid(net, res_lam, gammas)
    res = phyloNetworklm_BM(X, Y, V; msng=msng, ind=ind)
    res.lambda = res_lam
    res.model = "scalingHybrid"
    return res
end


"""
    phyloNetworklm(f, fr, net, model="BM",
        fTolRel=1e^-10, fTolAbs=1e^-10, xTolRel=1e^-10, xTolAbs=1e^-10,
        startingValue=0.5)`

Phylogenetic regression, using the correlation structure induced by the network.

Returns an object of class [`PhyloNetworkLinearModel`](@ref). See documentation for this type and
example to see all the functions that can be applied to it.

# Arguments
* `f::Formula`: formula to use for the regression (see the `DataFrame` package)
* `fr::AbstractDataFrame`: DataFrame containing the data and regressors at the tips. It should have an extra column labelled "tipNames", that gives the names of the taxa for each observation.
* `net::HybridNetwork`: phylogenetic network to use. Should have labelled tips.
* `model::AbstractString="BM"`: the model to use, "BM" being the default and only available model for now. If the entry is a TREE, then "lambda" can fit a Pagel's lambda model.
* `no_names::Bool=false`: if `true`, force the function to ignore the tips names. The data is then assumed to be in the same order as the tips of the network. Default to false, setting it to true is dangerous, and strongly discouraged.
If `model="lambda"`, there are a few more parameters to control the optimization in the parameter:
* `fTolRel::AbstractFloat=1e-10`: relative tolerance on the likelihood value for the optimization in lambda.
* `fTolAbs::AbstractFloat=1e-10`: absolute tolerance on the likelihood value for the optimization in lambda.
* `xTolRel::AbstractFloat=1e-10`: relative tolerance on the parameter value for the optimization in lambda.
* `xTolAbs::AbstractFloat=1e-10`: absolute tolerance on the parameter value for the optimization in lambda.
* `startingValue::Real=0.5`: the starting value for the parameter in the optimization in lambda.

# Examples
```jldoctest
julia> using DataFrames # Needed to handle data frames.

julia> phy = readTopology(joinpath(Pkg.dir("PhyloNetworks"), "examples", "caudata_tree.txt"));

julia> dat = readtable(joinpath(Pkg.dir("PhyloNetworks"), "examples", "caudata_trait.txt"));

julia> fitBM = phyloNetworklm(@formula(trait ~ 1), dat, phy);

julia> fitBM # Shows a summary
DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,Array{Float64,2}}

Formula: trait ~ +1

Model: BM

Parameter(s) Estimates:
Sigma2: 0.00294521

Coefficients:
             Estimate Std.Error t value Pr(>|t|)
(Intercept)     4.679  0.330627 14.1519   <1e-31

Log Likelihood: -78.9611507833
AIC: 161.9223015666

julia> round(sigma2_estim(fitBM), 6) # rounding for jldoctest convenience
0.002945

julia> round(mu_estim(fitBM), 4)
4.679

julia> round(loglikelihood(fitBM), 10)
-78.9611507833

julia> round(aic(fitBM), 10)
161.9223015666

julia> round(aicc(fitBM), 10)
161.9841572367

julia> round(bic(fitBM), 10)
168.4887090241

julia> coef(fitBM)
1-element Array{Float64,1}:
 4.679

julia> confint(fitBM)
1×2 Array{Float64,2}:
 4.02696  5.33104

julia> abs(round(r2(fitBM), 10)) # absolute value for jldoctest convenience
0.0

julia> abs(round(adjr2(fitBM), 10))
0.0

julia> vcov(fitBM)
1×1 Array{Float64,2}:
 0.109314

julia> residuals(fitBM)
197-element Array{Float64,1}:
 -0.237648
 -0.357937
 -0.159387
 -0.691868
 -0.323977
 -0.270452
 -0.673486
 -0.584654
 -0.279882
 -0.302175
  ⋮
 -0.777026
 -0.385121
 -0.443444
 -0.327303
 -0.525953
 -0.673486
 -0.603158
 -0.211712
 -0.439833

julia> model_response(fitBM)
197-element Array{Float64,1}:
 4.44135
 4.32106
 4.51961
 3.98713
 4.35502
 4.40855
 4.00551
 4.09434
 4.39912
 4.37682
 ⋮
 3.90197
 4.29388
 4.23555
 4.3517
 4.15305
 4.00551
 4.07584
 4.46729
 4.23917

julia> predict(fitBM)
197-element Array{Float64,1}:
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 ⋮
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679
 4.679

```

# See also
Type [`PhyloNetworkLinearModel`](@ref), Function [`ancestralStateReconstruction`](@ref)
""" #"
# Deal with formulas
function phyloNetworklm(f::Formula,
                        fr::AbstractDataFrame,
                        net::HybridNetwork;
                        model="BM"::AbstractString,
                        no_names=false::Bool,
                        ftolRel=fRelTr::AbstractFloat,
                        xtolRel=xRelTr::AbstractFloat,
                        ftolAbs=fAbsTr::AbstractFloat,
                        xtolAbs=xAbsTr::AbstractFloat,
                        startingValue=0.5::Real,
                        fixedValue=Nullable{Real}()::Nullable{Real})
    # Match the tips names: make sure that the data provided by the user will
    # be in the same order as the ordered tips in matrix V.
    preorder!(net)
    if no_names # The names should not be taken into account.
        ind = [0]
        info("""As requested (no_names=true), I am ignoring the tips names
             in the network and in the dataframe.""")
    elseif (any(tipLabels(net) == "") || !any(DataFrames.names(fr) .== :tipNames))
        if (any(tipLabels(net) == "") && !any(DataFrames.names(fr) .== :tipNames))
            error("""The network provided has no tip names, and the input dataframe has
                  no column labelled tipNames, so I can't match the data on the network
                  unambiguously. If you are sure that the tips of the network are in the
                  same order as the values of the dataframe provided, then please re-run
                  this function with argument no_name=true.""")
        end
        if any(tipLabels(net) == "")
            error("""The network provided has no tip names, so I can't match the data
                  on the network unambiguously. If you are sure that the tips of the
                  network are in the same order as the values of the dataframe provided,
                  then please re-run this function with argument no_name=true.""")
        end
        if !any(DataFrames.names(fr) .== :tipNames)
            error("""The input dataframe has no column labelled tipNames, so I can't
                  match the data on the network unambiguously. If you are sure that the
                  tips of the network are in the same order as the values of the dataframe
                  provided, then please re-run this function with argument no_name=true.""")
        end
    else
        #        ind = indexin(V.tipNames, fr[:tipNames])
        ind = indexin(fr[:tipNames], tipLabels(net))
        if any(ind == 0) || length(unique(ind)) != length(ind)
            error("""Tips names of the network and names provided in column tipNames
                  of the dataframe do not match.""")
        end
        #   fr = fr[ind, :]
    end
    # Find the regression matrix and answer vector
    mf = ModelFrame(f,fr)
    if isequal(f.rhs, -1) # If there are no regressors
        mm = ModelMatrix(zeros(size(mf.df, 1), 0), [0])
    else
        mm = ModelMatrix(mf)
    end
    Y = convert(Vector{Float64},DataFrames.model_response(mf))
    # Fit the model (Method copied from DataFrame/src/statsmodels/statsmodels.jl, lines 47-58)
    DataFrames.DataFrameRegressionModel(phyloNetworklm(mm.m, Y, net;
                                                       msng=mf.msng, model=model, ind=ind,
                                                       startingValue=startingValue, fixedValue=fixedValue), mf, mm)
    #    # Create the object
    #    phyloNetworkLinPredModel(DataFrames.DataFrameRegressionModel(fit, mf, mm),
    #    fit.V, fit.Vy, fit.RL, fit.Y, fit.X, fit.logdetVy, ind, mf.msng)
end

### Methods on type phyloNetworkRegression

## Un-changed Quantities
# Coefficients of the regression
StatsBase.coef(m::PhyloNetworkLinearModel) = coef(m.lm)
# Number of observations
StatsBase.nobs(m::PhyloNetworkLinearModel) = nobs(m.lm)
# vcov matrix
StatsBase.vcov(m::PhyloNetworkLinearModel) = vcov(m.lm)
# Standart error
StatsBase.stderr(m::PhyloNetworkLinearModel) = stderr(m.lm)
# Confidence Intervals
StatsBase.confint(m::PhyloNetworkLinearModel; level=0.95::Real) = confint(m.lm, level)
# coef table (coef, stderr, confint)
function StatsBase.coeftable(m::PhyloNetworkLinearModel)
    if size(m.lm.pp.X, 2) == 0
        return CoefTable([0], ["Fixed Value"], ["(Intercept)"])
    else
        coeftable(m.lm)
    end
end
# Degrees of freedom for residuals
StatsBase.dof_residual(m::PhyloNetworkLinearModel) =  nobs(m) - length(coef(m))
# Degrees of freedom consumed in the model
function StatsBase.dof(m::PhyloNetworkLinearModel)
    res = length(coef(m)) + 1 # (+1: dispersion parameter)
    if (m.model == "lambda")
        res += 1 # lambda is one parameter
    end
    return res
end
# Deviance (sum of squared residuals with metric V)
StatsBase.deviance(m::PhyloNetworkLinearModel) = deviance(m.lm)

## Changed Quantities
# Compute the residuals
# (Rescaled by cholesky of variance between tips)
StatsBase.residuals(m::PhyloNetworkLinearModel) = m.RL * residuals(m.lm)
# Tip data
StatsBase.model_response(m::PhyloNetworkLinearModel) = m.Y
# Predicted values at the tips
# (rescaled by cholesky of tips variances)
StatsBase.predict(m::PhyloNetworkLinearModel) = m.RL * predict(m.lm)
#Log likelihood of the fitted linear model
StatsBase.loglikelihood(m::PhyloNetworkLinearModel) =  loglikelihood(m.lm) - 1/2 * m.logdetVy
# Null  Deviance (sum of squared residuals with metric V)
# REMARK Not just the null deviance of the cholesky regression
# Might be something better to do than this, though.
function StatsBase.nulldeviance(m::PhyloNetworkLinearModel)
    vo = ones(length(m.Y), 1)
    vo = m.RL \ vo
    bo = inv(vo'*vo)*vo'*model_response(m.lm)
    ro = model_response(m.lm) - vo*bo
    return sum(ro.^2)
end
# Null Log likelihood (null model with only the intercept)
# Same remark
function StatsBase.nullloglikelihood(m::PhyloNetworkLinearModel)
    n = length(m.Y)
    return -n/2 * (log(2*pi * nulldeviance(m)/n) + 1) - 1/2 * m.logdetVy
end
# coefficient of determination (1 - SS_res/SS_null)
# Copied from GLM.jl/src/lm.jl, line 139
StatsBase.r2(m::PhyloNetworkLinearModel) = 1 - deviance(m)/nulldeviance(m)
# adjusted coefficient of determination
# Copied from GLM.jl/src/lm.jl, lines 141-146
function StatsBase.adjr2(obj::PhyloNetworkLinearModel)
    n = nobs(obj)
    # dof() includes the dispersion parameter
    p = dof(obj) - 1
    1 - (1 - r2(obj))*(n-1)/(n-p)
end

## REMARK
# As PhyloNetworkLinearModel <: LinPredModel, the following functions are automatically defined:
# aic, aicc, bic

## New quantities
# ML estimate for variance of the BM
"""
`sigma2_estim(m::PhyloNetworkLinearModel)`
Estimated variance for a fitted object.
"""
  sigma2_estim(m::PhyloNetworkLinearModel) = deviance(m.lm) / nobs(m)
  # Need to be adapted manually to DataFrameRegressionModel beacouse it's a new function
  sigma2_estim{T<:DataFrames.AbstractFloatMatrix}(m::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T}) = sigma2_estim(m.model)
  # ML estimate for ancestral state of the BM
  """
  `mu_estim(m::PhyloNetworkLinearModel)`
  Estimated root value for a fitted object.
  """
  function mu_estim(m::PhyloNetworkLinearModel)
      warn("""You fitted the data against a custom matrix, so I have no way of
           knowing which column is your intercept (column of ones).
           I am using the first coefficient for ancestral mean mu by convention,
           but that might not be what you are looking for.""")
      if size(m.lm.pp.X,2) == 0
          return 0
      else
          return coef(m)[1]
      end
  end
  # Need to be adapted manually to DataFrameRegressionModel beacouse it's a new function
  function mu_estim{T<:DataFrames.AbstractFloatMatrix}(m::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T})
      if (!m.mf.terms.intercept)
          error("The fit was done without intercept, so I cannot estimate mu")
      end
      return coef(m)[1]
  end
  # Lambda estim
  """
  `lambda_estim(m::PhyloNetworkLinearModel)`
  Estimated lambda parameter for a fitted object.
  """
  lambda_estim(m::PhyloNetworkLinearModel) = m.lambda
  lambda_estim{T<:DataFrames.AbstractFloatMatrix}(m::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T}) = lambda_estim(m.model)

  ### Functions specific to DataFrameRegressionModel
  DataFrames.ModelFrame(m::DataFrames.DataFrameRegressionModel) = m.mf
  DataFrames.ModelMatrix(m::DataFrames.DataFrameRegressionModel) = m.mm
  DataFrames.Formula(m::DataFrames.DataFrameRegressionModel) = Formula(m.mf.terms)

  ### Print the results
  # Variance
  function paramstable(m::PhyloNetworkLinearModel)
      Sig = sigma2_estim(m)
      res = "Sigma2: " * @sprintf("%.6g", Sig)
      if (m.model == "lambda")
          Lamb = lambda_estim(m)
          res = res*"\nLambda: " * @sprintf("%.6g", Lamb)
      end
      return(res)
  end
  function Base.show(io::IO, obj::PhyloNetworkLinearModel)
      println(io, "$(typeof(obj)):\n\nParameter(s) Estimates:\n", paramstable(obj), "\n\nCoefficients:\n", coeftable(obj))
  end
  # For DataFrameModel. Copied from DataFrames/jl/src/statsmodels/statsmodels.jl, lines 101-118
  function Base.show{T<:DataFrames.AbstractFloatMatrix}(io::IO, model::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T})
      ct = coeftable(model)
      println(io, "$(typeof(model))")
      println(io)
      println(io, Formula(model.mf.terms))
      println(io)
      println(io, "Model: $(model.model.model)")
      println(io)
      println(io,"Parameter(s) Estimates:")
      println(io, paramstable(model.model))
      println(io)
      println(io,"Coefficients:")
      show(io, ct)
      println(io)
      println(io, "Log Likelihood: "*"$(round(loglikelihood(model), 10))")
      println(io, "AIC: "*"$(round(aic(model), 10))")
  end


  ## Deprecated
  # function StatsBase.vcov(obj::PhyloNetworkLinearModel)
  #    sigma2_estim(obj) * inv(obj.X' * obj.X)
  # end
  #function StatsBase.vcov(obj::phyloNetworkLinPredModel)
  #   sigma2_estim(obj) * inv(obj.X' * obj.X)
  #end
  #StatsBase.stderr(m::phyloNetworkLinPredModel) = sqrt(diag(vcov(m)))
  # Confidence intervals on coeficients
  # function StatsBase.confint(obj::PhyloNetworkLinearModel, level=0.95::Real)
  #     hcat(coef(obj),coef(obj)) + stderr(obj) *
  #     quantile(TDist(dof_residual(obj)), (1. - level)/2.) * [1. -1.]
  # end
  # Log likelihood of the fitted BM
  # StatsBase.loglikelihood(m::PhyloNetworkLinearModel) = - 1 / 2 * (nobs(m) + nobs(m) * log(2 * pi) + nobs(m) * log(sigma2_estim(m)) + m.logdetVy)
  #StatsBase.loglikelihood(m::phyloNetworkLinPredModel) = - 1 / 2 * (nobs(m) + nobs(m) * log(2 * pi) + nobs(m) * log(sigma2_estim(m)) + m.logdetVy)
  # Coefficients
  # function StatsBase.coeftable(mm::PhyloNetworkLinearModel)
  #     cc = coef(mm)
  #     se = stderr(mm)
  #     tt = cc ./ se
  #     CoefTable(hcat(cc,se,tt,ccdf(FDist(1, dof_residual(mm)), abs2(tt))),
  #               ["Estimate","Std.Error","t value", "Pr(>|t|)"],
  #               ["x$i" for i = 1:size(mm.lm.pp.X, 2)], 4)
  # end

  ###############################################################################
  ###############################################################################
  ## Anova
  ###############################################################################
  ###############################################################################


  """
  `anova(objs::PhyloNetworkLinearModel...)`

  Takes several nested fits of the same data, and computes the F statistic for each
  pair of models.

  The fits must be results of function [`phyloNetworklm`](@ref) called on the same
  data, for models that have more and more effects.

  Returns a DataFrame object with the anova table.
  """
  function anova{T<:DataFrames.AbstractFloatMatrix}(objs::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T}...)
      objsModels = [obj.model for obj in objs]
      return(anova(objsModels...))
  end

  function anova(objs::PhyloNetworkLinearModel...)
      anovaTable = Array{Any}(length(objs)-1, 6)
      ## Compute binary statistics
      for i in 1:(length(objs) - 1)
        anovaTable[i, :] = anovaBin(objs[i], objs[i+1])
      end
      ## Transform into a DataFrame
      anovaTable = DataFrame(anovaTable)
      names!(anovaTable, [:dof_res, :RSS, :dof, :SS, :F, Symbol("Pr(>F)")])
      return(anovaTable)
  end

  function anovaBin(obj1::PhyloNetworkLinearModel, obj2::PhyloNetworkLinearModel)
      length(coef(obj1)) < length(coef(obj2)) || error("Models must be nested, from the smallest to the largest.")
      ## residuals
      dof2 = dof_residual(obj2)
      dev2 = deviance(obj2)
      ## reducted residuals
      dof1 = dof_residual(obj1) - dof2
      dev1 = deviance(obj1) - dev2
      ## Compute statistic
      F = (dev1 / dof1) / (dev2 / dof2)
      pval = ccdf(FDist(dof1, dof2), F)
      return([dof2, dev2, dof1, dev1, F, pval])
end

# Lambda estim
"""
`lambda_estim(m::PhyloNetworkLinearModel)`
Estimated lambda parameter for a fitted object.
"""
lambda_estim(m::PhyloNetworkLinearModel) = m.lambda
lambda_estim{T<:DataFrames.AbstractFloatMatrix}(m::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T}) = lambda_estim(m.model)

### Functions specific to DataFrameRegressionModel
DataFrames.ModelFrame(m::DataFrames.DataFrameRegressionModel) = m.mf
DataFrames.ModelMatrix(m::DataFrames.DataFrameRegressionModel) = m.mm
DataFrames.Formula(m::DataFrames.DataFrameRegressionModel) = Formula(m.mf.terms)

### Print the results
# Variance
function paramstable(m::PhyloNetworkLinearModel)
    Sig = sigma2_estim(m)
    res = "Sigma2: " * @sprintf("%.6g", Sig)
    if (m.model == "lambda" || m.model == "scalingHybrid")
        Lamb = lambda_estim(m)
        res = res*"\nLambda: " * @sprintf("%.6g", Lamb)
    end
    return(res)
end
function Base.show(io::IO, obj::PhyloNetworkLinearModel)
    println(io, "$(typeof(obj)):\n\nParameter(s) Estimates:\n", paramstable(obj), "\n\nCoefficients:\n", coeftable(obj))
end
# For DataFrameModel. Copied from DataFrames/jl/src/statsmodels/statsmodels.jl, lines 101-118
function Base.show{T<:DataFrames.AbstractFloatMatrix}(io::IO, model::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T})
    ct = coeftable(model)
    println(io, "$(typeof(model))")
    println(io)
    println(io, Formula(model.mf.terms))
    println(io)
    println(io, "Model: $(model.model.model)")
    println(io)
    println(io,"Parameter(s) Estimates:")
    println(io, paramstable(model.model))
    println(io)
    println(io,"Coefficients:")
    show(io, ct)
    println(io)
    println(io, "Log Likelihood: "*"$(round(loglikelihood(model), 10))")
    println(io, "AIC: "*"$(round(aic(model), 10))")
end


## Deprecated
# function StatsBase.vcov(obj::PhyloNetworkLinearModel)
#    sigma2_estim(obj) * inv(obj.X' * obj.X)
# end
#function StatsBase.vcov(obj::phyloNetworkLinPredModel)
#   sigma2_estim(obj) * inv(obj.X' * obj.X)
#end
#StatsBase.stderr(m::phyloNetworkLinPredModel) = sqrt(diag(vcov(m)))
# Confidence intervals on coeficients
# function StatsBase.confint(obj::PhyloNetworkLinearModel, level=0.95::Real)
#     hcat(coef(obj),coef(obj)) + stderr(obj) *
#     quantile(TDist(dof_residual(obj)), (1. - level)/2.) * [1. -1.]
# end
# Log likelihood of the fitted BM
# StatsBase.loglikelihood(m::PhyloNetworkLinearModel) = - 1 / 2 * (nobs(m) + nobs(m) * log(2 * pi) + nobs(m) * log(sigma2_estim(m)) + m.logdetVy)
#StatsBase.loglikelihood(m::phyloNetworkLinPredModel) = - 1 / 2 * (nobs(m) + nobs(m) * log(2 * pi) + nobs(m) * log(sigma2_estim(m)) + m.logdetVy)
# Coefficients
# function StatsBase.coeftable(mm::PhyloNetworkLinearModel)
#     cc = coef(mm)
#     se = stderr(mm)
#     tt = cc ./ se
#     CoefTable(hcat(cc,se,tt,ccdf(FDist(1, dof_residual(mm)), abs2(tt))),
#               ["Estimate","Std.Error","t value", "Pr(>|t|)"],
#               ["x$i" for i = 1:size(mm.lm.pp.X, 2)], 4)
# end

###############################################################################
###############################################################################
## Ancestral State Reconstruction
###############################################################################
###############################################################################
# Class for reconstructed states on a network
"""
`ReconstructedStates`

Type containing the inferred information about the law of the ancestral states
given the observed tips values. The missing tips are considered as ancestral states.

The following functions can be applied to it:
[`expectations`](@ref) (vector of expectations at all nodes), `stderr` (the standard error),
`predint` (the prediction interval).

The `ReconstructedStates` object has fields: `traits_nodes`, `variances_nodes`, `NodeNumbers`, `traits_tips`, `tipNumbers`, `model`.
Type in "?ReconstructedStates.field" to get help on a specific field.
"""
struct ReconstructedStates
    "traits_nodes: the infered expectation of 'missing' values (ancestral nodes and missing tips)"
    traits_nodes::Vector # Nodes are actually "missing" data (including tips)
    "variances_nodes: the variance covariance matrix between all the 'missing' nodes"
    variances_nodes::Matrix
    "NodeNumbers: vector of the nodes numbers, in the same order as `traits_nodes`"
    NodeNumbers::Vector{Int}
    "traits_tips: the observed traits values at the tips"
    traits_tips::Vector # Observed values at tips
    "TipNumbers: vector of tips numbers, in the same order as `traits_tips`"
    TipNumbers::Vector # Observed tips only
    "model (Nullable): if not null, the `PhyloNetworkLinearModel` used for the computations."
    model::Nullable{PhyloNetworkLinearModel} # If empirical, the corresponding fitted object.
end

"""
`expectations(obj::ReconstructedStates)`
Estimated reconstructed states at the nodes and tips.
"""
function expectations(obj::ReconstructedStates)
    return DataFrame(nodeNumber = [obj.NodeNumbers; obj.TipNumbers], condExpectation = [obj.traits_nodes; obj.traits_tips])
end

"""
`expectationsPlot(obj::ReconstructedStates)`
Compute and format the expected reconstructed states for the plotting function.
The resulting dataframe can be readily used as a `nodeLabel` argument to
`plot`.
"""
function expectationsPlot(obj::ReconstructedStates)
    expe = expectations(obj)
    expetxt = Array{AbstractString}(size(expe, 1))
    for i=1:size(expe, 1)
        expetxt[i] = string(round(expe[i, 2], 2))
    end
    return DataFrame(nodeNumber = [obj.NodeNumbers; obj.TipNumbers], PredInt = expetxt)
end

StatsBase.stderr(obj::ReconstructedStates) = sqrt.(diag(obj.variances_nodes))

"""
`predint(obj::ReconstructedStates, level=0.95::Real)`
Prediction intervals with level `level` for internal nodes and missing tips.
"""
function predint(obj::ReconstructedStates, level=0.95::Real)
    if isnull(obj.model)
        qq = quantile(Normal(), (1. - level)/2.)
    else
        qq = quantile(TDist(dof_residual(get(obj.model))), (1. - level)/2.)
        #       warn("As the variance is estimated, the predictions intervals are not exact, and should probably be larger.")
    end
    tmpnode = hcat(obj.traits_nodes, obj.traits_nodes) + stderr(obj) * qq * [1. -1.]
    return vcat(tmpnode, hcat(obj.traits_tips, obj.traits_tips))
end

function Base.show(io::IO, obj::ReconstructedStates)
    println(io, "$(typeof(obj)):\n",
            CoefTable(hcat(vcat(obj.NodeNumbers, obj.TipNumbers), vcat(obj.traits_nodes, obj.traits_tips), predint(obj)),
                      ["Node index", "Pred.", "Min.", "Max. (95%)"],
                      fill("", length(obj.NodeNumbers)+length(obj.TipNumbers))))
end

"""
`predintPlot(obj::ReconstructedStates, level=0.95::Real)`
Compute and format the prediction intervals for the plotting function.
The resulting dataframe can be readily used as a `nodeLabel` argument to
`plot`.
"""
function predintPlot(obj::ReconstructedStates, level=0.95::Real)
    pri = predint(obj, level)
    pritxt = Array{AbstractString}(size(pri, 1))
    for i=1:length(obj.NodeNumbers)
        pritxt[i] = "[" * string(round(pri[i, 1], 2)) * ", " * string(round(pri[i, 2], 2)) * "]"
    end
    for i=(length(obj.NodeNumbers)+1):size(pri, 1)
        pritxt[i] = string(round(pri[i, 1], 2))
    end
    return DataFrame(nodeNumber = [obj.NodeNumbers; obj.TipNumbers], PredInt = pritxt)
end

# """
# 'plot(net::HybridNetwork, obj::ReconstructedStates; kwargs...)
#
# Plot the reconstructed states computed by function `ancestralStateReconstruction`
# on a network.
#
# # Arguments
# * `net::HybridNetwork`: a phylogenetic network.
# * `obj::ReconstructedStates`: the reconstructed states on the network.
# * `kwargs...`: further arguments to be passed to the netwotk `plot` function.
#
# See documentation for function `ancestralStateReconstruction(obj::PhyloNetworkLinearModel[, X_n::Matrix])` for examples.
#
# """
# function Gadfly.plot(net::HybridNetwork, obj::ReconstructedStates; kwargs...)
#   plot(net, nodeLabel = predintPlot(obj); kwargs...)
# end

"""
`ancestralStateReconstruction(net::HybridNetwork, Y::Vector, params::ParamsBM)`

Compute the conditional expectations and variances of the ancestral (un-observed)
traits values at the internal nodes of the phylogenetic network (`net`),
given the values of the traits at the tips of the network (`Y`) and some
known parameters of the process used for trait evolution (`params`, only BM with fixed root
works for now).

This function assumes that the parameters of the process are known. For a more general
function, see `ancestralStateReconstruction(obj::PhyloNetworkLinearModel[, X_n::Matrix])`.

"""
# Reconstruction from known BM parameters
function ancestralStateReconstruction(net::HybridNetwork,
                                      Y::Vector,
                                      params::ParamsBM)
    V = sharedPathMatrix(net)
    ancestralStateReconstruction(V, Y, params)
end

function ancestralStateReconstruction(V::MatrixTopologicalOrder,
                                      Y::Vector,
                                      params::ParamsBM)
    # Variances matrices
    Vy = V[:Tips]
    Vz = V[:InternalNodes]
    Vyz = V[:TipsNodes]
    R = cholfact(Vy)
    RL = R[:L]
    temp = RL \ Vyz
    # Vectors of means
    m_y = ones(size(Vy)[1]) .* params.mu # !! correct only if no predictor.
    m_z = ones(size(Vz)[1]) .* params.mu # !! works if BM no shift.
    # Actual computation
    ancestralStateReconstruction(Vz, temp, RL,
                                 Y, m_y, m_z,
                                 V.internalNodeNumbers,
                                 V.tipNumbers,
                                 params.sigma2)
end

# Reconstruction from all the needed quantities
function ancestralStateReconstruction(Vz::Matrix,
                                      VyzVyinvchol::Matrix,
                                      RL::LowerTriangular,
                                      Y::Vector, m_y::Vector, m_z::Vector,
                                      NodeNumbers::Vector,
                                      TipNumbers::Vector,
                                      sigma2::Real,
                                      add_var=zeros(size(Vz))::Matrix, # Additional variance for BLUP
                                      model=Nullable{PhyloNetworkLinearModel}()::Nullable{PhyloNetworkLinearModel})
    m_z_cond_y = m_z + VyzVyinvchol' * (RL \ (Y - m_y))
    V_z_cond_y = sigma2 .* (Vz - VyzVyinvchol' * VyzVyinvchol)
    ReconstructedStates(m_z_cond_y, V_z_cond_y + add_var, NodeNumbers, Y, TipNumbers, model)
end

# """
# `ancestralStateReconstruction(obj::PhyloNetworkLinearModel, X_n::Matrix)`
# Function to find the ancestral traits reconstruction on a network, given an
# object fitted by function phyloNetworklm, and some predictors expressed at all the nodes of the network.
#
# - obj: a PhyloNetworkLinearModel object, or a
# DataFrameRegressionModel{PhyloNetworkLinearModel}, if data frames were used.
# - X_n a matrix with as many columns as the number of predictors used, and as
# many lines as the number of unknown nodes or tips.
#
# Returns an object of type ancestralStateReconstruction.
# """

# Empirical reconstruciton from a fitted object
# TO DO: Handle the order of internal nodes for matrix X_n
function ancestralStateReconstruction(obj::PhyloNetworkLinearModel, X_n::Matrix)
    if (size(X_n)[2] != length(coef(obj)))
        error("""The number of predictors for the ancestral states (number of columns of X_n)
              does not match the number of predictors at the tips.""")
    end
    if (size(X_n)[1] != length(obj.V.internalNodeNumbers) + sum(.!obj.msng))
        error("""The number of lines of the predictors does not match
              the number of nodes plus the number of missing tips.""")
    end
    m_y = predict(obj)
    m_z = X_n * coef(obj)
    # If the tips were re-organized, do the same for Vyz
    if (obj.ind != [0])
#       iii = indexin(1:length(obj.msng), obj.ind[obj.msng])
#       iii = iii[iii .> 0]
#       jjj = [1:length(obj.V.internalNodeNumbers); indexin(1:length(obj.msng), obj.ind[!obj.msng])]
#       jjj = jjj[jjj .> 0]
#       Vyz = Vyz[iii, jjj]
        Vyz = obj.V[:TipsNodes, obj.ind, obj.msng]
        missingTipNumbers = obj.V.tipNumbers[obj.ind][.!obj.msng]
        nmTipNumbers = obj.V.tipNumbers[obj.ind][obj.msng]
    else
        warn("""There were no indication for the position of the tips on the network.
             I am assuming that they are given in the same order.
             Please check that this is what you intended.""")
        Vyz = obj.V[:TipsNodes, collect(1:length(obj.V.tipNumbers)), obj.msng]
        missingTipNumbers = obj.V.tipNumbers[.!obj.msng]
        nmTipNumbers = obj.V.tipNumbers[obj.msng]
    end
    temp = obj.RL \ Vyz
    U = X_n - temp' * (obj.RL \ obj.X)
    add_var = U * vcov(obj) * U'
    # Warn about the prediction intervals
    warn("""These prediction intervals show uncertainty in ancestral values,
         assuming that the estimated variance rate of evolution is correct.
         Additional uncertainty in the estimation of this variance rate is
         ignored, so prediction intervals should be larger.""")
    # Actual reconstruction
    ancestralStateReconstruction(obj.V[:InternalNodes, obj.ind, obj.msng],
                                 temp,
                                 obj.RL,
                                 obj.Y,
                                 m_y,
                                 m_z,
                                 [obj.V.internalNodeNumbers; missingTipNumbers],
                                 nmTipNumbers,
                                 sigma2_estim(obj),
                                 add_var,
                                 obj)
end

"""
`ancestralStateReconstruction(obj::PhyloNetworkLinearModel[, X_n::Matrix])`

Function to find the ancestral traits reconstruction on a network, given an
object fitted by function [`phyloNetworklm`](@ref). By default, the function assumes
that the regressor is just an intercept. If the value of the regressor for
all the ancestral states is known, it can be entered in X_n, a matrix with as
many columns as the number of predictors used, and as many lines as the number
of unknown nodes or tips.

Returns an object of type [`ReconstructedStates`](@ref).
See documentation for this type and examples for functions that can be applied to it.

# Examples

```jldoctest
julia> using DataFrames # Needed to use handle data frames

julia> phy = readTopology(joinpath(Pkg.dir("PhyloNetworks"), "examples", "carnivores_tree.txt"));

julia> dat = readtable(joinpath(Pkg.dir("PhyloNetworks"), "examples", "carnivores_trait.txt"));

julia> fitBM = phyloNetworklm(@formula(trait ~ 1), dat, phy);

julia> ancStates = ancestralStateReconstruction(fitBM) # Should produce a warning, as variance is unknown.
WARNING: These prediction intervals show uncertainty in ancestral values,
assuming that the estimated variance rate of evolution is correct.
Additional uncertainty in the estimation of this variance rate is
ignored, so prediction intervals should be larger.
PhyloNetworks.ReconstructedStates:
     Node index     Pred.       Min. Max. (95%)
           -5.0   1.32139  -0.288423     2.9312
           -8.0   1.03258  -0.539072    2.60423
           -7.0   1.41575 -0.0934395    2.92495
           -6.0   1.39417 -0.0643135    2.85265
           -4.0   1.39961 -0.0603343    2.85955
           -3.0   1.51341  -0.179626    3.20644
          -13.0    5.3192    3.96695    6.67145
          -12.0   4.51176    2.94268    6.08085
          -16.0   1.50947  0.0290151    2.98992
          -15.0   1.67425   0.241696    3.10679
          -14.0   1.80309   0.355568     3.2506
          -11.0    2.7351    1.21896    4.25123
          -10.0   2.73217    1.16545    4.29889
           -9.0   2.41132   0.639075    4.18357
           -2.0   2.04138 -0.0340955    4.11686
           14.0   1.64289    1.64289    1.64289
            8.0   1.67724    1.67724    1.67724
            5.0  0.331568   0.331568   0.331568
            2.0   2.27395    2.27395    2.27395
            4.0  0.275237   0.275237   0.275237
            6.0   3.39094    3.39094    3.39094
           13.0  0.355799   0.355799   0.355799
           15.0  0.542565   0.542565   0.542565
            7.0  0.773436   0.773436   0.773436
           10.0   6.94985    6.94985    6.94985
           11.0   4.78323    4.78323    4.78323
           12.0   5.33016    5.33016    5.33016
            1.0 -0.122604  -0.122604  -0.122604
           16.0   0.73989    0.73989    0.73989
            9.0   4.84236    4.84236    4.84236
            3.0    1.0695     1.0695     1.0695

julia> expectations(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ condExpectation │
├─────┼────────────┼─────────────────┤
│ 1   │ -5         │ 1.32139         │
│ 2   │ -8         │ 1.03258         │
│ 3   │ -7         │ 1.41575         │
│ 4   │ -6         │ 1.39417         │
│ 5   │ -4         │ 1.39961         │
│ 6   │ -3         │ 1.51341         │
│ 7   │ -13        │ 5.3192          │
│ 8   │ -12        │ 4.51176         │
⋮
│ 23  │ 15         │ 0.542565        │
│ 24  │ 7          │ 0.773436        │
│ 25  │ 10         │ 6.94985         │
│ 26  │ 11         │ 4.78323         │
│ 27  │ 12         │ 5.33016         │
│ 28  │ 1          │ -0.122604       │
│ 29  │ 16         │ 0.73989         │
│ 30  │ 9          │ 4.84236         │
│ 31  │ 3          │ 1.0695          │

julia> predint(ancStates)
31×2 Array{Float64,2}:
 -0.288423    2.9312
 -0.539072    2.60423
 -0.0934395   2.92495
 -0.0643135   2.85265
 -0.0603343   2.85955
 -0.179626    3.20644
  3.96695     6.67145
  2.94268     6.08085
  0.0290151   2.98992
  0.241696    3.10679
  ⋮
  0.542565    0.542565
  0.773436    0.773436
  6.94985     6.94985
  4.78323     4.78323
  5.33016     5.33016
 -0.122604   -0.122604
  0.73989     0.73989
  4.84236     4.84236
  1.0695      1.0695

julia> ## Format and plot the ancestral states:

julia> expectationsPlot(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ PredInt │
├─────┼────────────┼─────────┤
│ 1   │ -5         │ "1.32"  │
│ 2   │ -8         │ "1.03"  │
│ 3   │ -7         │ "1.42"  │
│ 4   │ -6         │ "1.39"  │
│ 5   │ -4         │ "1.4"   │
│ 6   │ -3         │ "1.51"  │
│ 7   │ -13        │ "5.32"  │
│ 8   │ -12        │ "4.51"  │
⋮
│ 23  │ 15         │ "0.54"  │
│ 24  │ 7          │ "0.77"  │
│ 25  │ 10         │ "6.95"  │
│ 26  │ 11         │ "4.78"  │
│ 27  │ 12         │ "5.33"  │
│ 28  │ 1          │ "-0.12" │
│ 29  │ 16         │ "0.74"  │
│ 30  │ 9          │ "4.84"  │
│ 31  │ 3          │ "1.07"  │

julia> plot(phy, nodeLabel = expectationsPlot(ancStates))
Plot(...)

julia> predintPlot(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ PredInt         │
├─────┼────────────┼─────────────────┤
│ 1   │ -5         │ "[-0.29, 2.93]" │
│ 2   │ -8         │ "[-0.54, 2.6]"  │
│ 3   │ -7         │ "[-0.09, 2.92]" │
│ 4   │ -6         │ "[-0.06, 2.85]" │
│ 5   │ -4         │ "[-0.06, 2.86]" │
│ 6   │ -3         │ "[-0.18, 3.21]" │
│ 7   │ -13        │ "[3.97, 6.67]"  │
│ 8   │ -12        │ "[2.94, 6.08]"  │
⋮
│ 23  │ 15         │ "0.54"          │
│ 24  │ 7          │ "0.77"          │
│ 25  │ 10         │ "6.95"          │
│ 26  │ 11         │ "4.78"          │
│ 27  │ 12         │ "5.33"          │
│ 28  │ 1          │ "-0.12"         │
│ 29  │ 16         │ "0.74"          │
│ 30  │ 9          │ "4.84"          │
│ 31  │ 3          │ "1.07"          │

julia> plot(phy, nodeLabel = predintPlot(ancStates))
Plot(...)

julia> ## Some tips may also be missing

julia> dat[[2, 5], :trait] = NA;

julia> fitBM = phyloNetworklm(@formula(trait ~ 1), dat, phy);

julia> ancStates = ancestralStateReconstruction(fitBM);
WARNING: These prediction intervals show uncertainty in ancestral values,
assuming that the estimated variance rate of evolution is correct.
Additional uncertainty in the estimation of this variance rate is
ignored, so prediction intervals should be larger.

julia> expectations(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ condExpectation │
├─────┼────────────┼─────────────────┤
│ 1   │ -5         │ 1.42724         │
│ 2   │ -8         │ 1.35185         │
│ 3   │ -7         │ 1.61993         │
│ 4   │ -6         │ 1.54198         │
│ 5   │ -4         │ 1.53916         │
│ 6   │ -3         │ 1.64984         │
│ 7   │ -13        │ 5.33508         │
│ 8   │ -12        │ 4.55109         │
⋮
│ 23  │ 15         │ 0.542565        │
│ 24  │ 7          │ 0.773436        │
│ 25  │ 10         │ 6.94985         │
│ 26  │ 11         │ 4.78323         │
│ 27  │ 12         │ 5.33016         │
│ 28  │ 1          │ -0.122604       │
│ 29  │ 16         │ 0.73989         │
│ 30  │ 9          │ 4.84236         │
│ 31  │ 3          │ 1.0695          │

julia> predint(ancStates)
31×2 Array{Float64,2}:
 -0.31245     3.16694
 -0.625798    3.3295
 -0.110165    3.35002
 -0.0710391   3.15501
 -0.0675924   3.14591
 -0.197236    3.49692
  3.89644     6.77373
  2.8741      6.22808
 -0.0358627   3.12834
  0.182594    3.2534
  ⋮
  0.542565    0.542565
  0.773436    0.773436
  6.94985     6.94985
  4.78323     4.78323
  5.33016     5.33016
 -0.122604   -0.122604
  0.73989     0.73989
  4.84236     4.84236
  1.0695      1.0695

julia> ## Format and plot the ancestral states:

julia> expectationsPlot(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ PredInt │
├─────┼────────────┼─────────┤
│ 1   │ -5         │ "1.43"  │
│ 2   │ -8         │ "1.35"  │
│ 3   │ -7         │ "1.62"  │
│ 4   │ -6         │ "1.54"  │
│ 5   │ -4         │ "1.54"  │
│ 6   │ -3         │ "1.65"  │
│ 7   │ -13        │ "5.34"  │
│ 8   │ -12        │ "4.55"  │
⋮
│ 23  │ 15         │ "0.54"  │
│ 24  │ 7          │ "0.77"  │
│ 25  │ 10         │ "6.95"  │
│ 26  │ 11         │ "4.78"  │
│ 27  │ 12         │ "5.33"  │
│ 28  │ 1          │ "-0.12" │
│ 29  │ 16         │ "0.74"  │
│ 30  │ 9          │ "4.84"  │
│ 31  │ 3          │ "1.07"  │

julia> plot(phy, nodeLabel = expectationsPlot(ancStates))
Plot(...)

julia> predintPlot(ancStates)
31×2 DataFrames.DataFrame
│ Row │ nodeNumber │ PredInt         │
├─────┼────────────┼─────────────────┤
│ 1   │ -5         │ "[-0.31, 3.17]" │
│ 2   │ -8         │ "[-0.63, 3.33]" │
│ 3   │ -7         │ "[-0.11, 3.35]" │
│ 4   │ -6         │ "[-0.07, 3.16]" │
│ 5   │ -4         │ "[-0.07, 3.15]" │
│ 6   │ -3         │ "[-0.2, 3.5]"   │
│ 7   │ -13        │ "[3.9, 6.77]"   │
│ 8   │ -12        │ "[2.87, 6.23]"  │
⋮
│ 23  │ 15         │ "0.54"          │
│ 24  │ 7          │ "0.77"          │
│ 25  │ 10         │ "6.95"          │
│ 26  │ 11         │ "4.78"          │
│ 27  │ 12         │ "5.33"          │
│ 28  │ 1          │ "-0.12"         │
│ 29  │ 16         │ "0.74"          │
│ 30  │ 9          │ "4.84"          │
│ 31  │ 3          │ "1.07"          │

julia> plot(phy, nodeLabel = predintPlot(ancStates))
Plot(...)
```
"""
# Default reconstruction for a simple BM (known predictors)
function ancestralStateReconstruction(obj::PhyloNetworkLinearModel)
    if ((size(obj.X)[2] != 1) || !any(obj.X .== 1)) # Test if the regressor is just an intercept.
        error("""Predictor(s) other than a plain intercept are used in this `PhyloNetworkLinearModel` object.
    These predictors are unobserved at ancestral nodes, so they cannot be used
    for the ancestral state reconstruction. If these ancestral predictor values
    are known, please provide them as a matrix argument to the function.
    Otherwise, you might consider doing a multivariate linear regression (not implemented yet).""")
    end
  X_n = ones((length(obj.V.internalNodeNumbers) + sum(.!obj.msng), 1))
    ancestralStateReconstruction(obj, X_n)
end
# For a DataFrameRegressionModel
function ancestralStateReconstruction{T<:DataFrames.AbstractFloatMatrix}(obj::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T})
    ancestralStateReconstruction(obj.model)
end
function ancestralStateReconstruction{T<:DataFrames.AbstractFloatMatrix}(obj::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,T}, X_n::Matrix)
    ancestralStateReconstruction(obj.model, X_n::Matrix)
end

"""
`ancestralStateReconstruction(fr::AbstractDataFrame, net::HybridNetwork; kwargs...)`

Function to find the ancestral traits reconstruction on a network, given some data at the tips.
Uses function [`phyloNetworklm`](@ref) to perform a phylogenetic regression of the data against an
intercept (amounts to fitting an evolutionary model on the network, BM being the only option
available for now).

See documentation on [`phyloNetworklm`](@ref) and `ancestralStateReconstruction(obj::PhyloNetworkLinearModel[, X_n::Matrix])`
for further details.

Returns an object of type [`ReconstructedStates`](@ref).
"""
# Deal with formulas
function ancestralStateReconstruction(fr::AbstractDataFrame,
                                      net::HybridNetwork;
                                      kwargs...)
    nn = names(fr)
    datpos = nn .!= :tipNames
    if sum(datpos) > 1
        error("""Besides one column labelled 'tipNames', the dataframe fr should have
              only one column, corresponding to the data at the tips of the network.""")
    end
    f = Formula(nn[datpos][1], 1)
    reg = phyloNetworklm(f, fr, net; kwargs...)
    return ancestralStateReconstruction(reg)
end

# # Default reconstruction for a simple BM
# function ancestralStateReconstruction(obj::PhyloNetworkLinearModel, mu::Real)
#   m_y = predict(obj)
#   m_z = ones(size(obj.V.internalNodeNumbers)[1]) .* mu # !! works if BM no shift.
#   ancestralStateReconstruction(obj, m_y, m_z)
# end
# # Handling the ancestral mean
# function ancestralStateReconstruction(obj::PhyloNetworkLinearModel)
#   mu = mu_estim(obj) # Produce a warning if intercept is unknown.
#   ancestralStateReconstruction(obj, mu)
# end
# # For a DataFrameRegressionModel
# function ancestralStateReconstruction(obj::DataFrames.DataFrameRegressionModel{PhyloNetworks.PhyloNetworkLinearModel,Float64})
#   mu = mu_estim(obj) # Produces an error if intercept is not here.
#   ancestralStateReconstruction(obj.model, mu)
# end

#################################################
## Old version of phyloNetworklm (naive)
#################################################

# function phyloNetworklmNaive(X::Matrix, Y::Vector, net::HybridNetwork, model="BM"::AbstractString)
#   # Geting variance covariance
#   V = sharedPathMatrix(net)
#   Vy = extractVarianceTips(V, net)
#   # Needed quantities (naive)
#   ntaxa = length(Y)
#   Vyinv = inv(Vy)
#   XtVyinv = X' * Vyinv
#   logdetVy = logdet(Vy)
#        # beta hat
#   betahat = inv(XtVyinv * X) * XtVyinv * Y
#        # sigma2 hat
#   fittedValues =  X * betahat
#   residuals = Y - fittedValues
#   sigma2hat = 1/ntaxa * (residuals' * Vyinv * residuals)
#        # log likelihood
#   loglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(sigma2hat) + logdetVy)
#   # Result
# # res = phyloNetworkRegression(betahat, sigma2hat[1], loglik[1], V, Vy, fittedValues, residuals)
#   return((betahat, sigma2hat[1], loglik[1], V, Vy, logdetVy, fittedValues, residuals))
# end
