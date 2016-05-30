# functions to describe a HybridNetwork object to avoid accessing the attributes directly
# Claudia August 2015

"""
`tipLabels(net::HybridNetwork)`

returns a vector of taxon names (at the leaves) from a HybridNetwork object
"""
function tipLabels(net::HybridNetwork)
    return ASCIIString[l.name for l in net.leaf] # AbstractString does not work for use by tree2Matrix
end



"""
`dfObsExpCF(d::DataCF)`

return a data frame with the observed and expected CF after estimation of a network with snaq(T,d).
"""
function dfObsExpCF(d::DataCF)
    df=DataFrame(tx1 = [q.taxon[1] for q in d.quartet],
                 tx2 = [q.taxon[2] for q in d.quartet],
                 tx3 = [q.taxon[3] for q in d.quartet],
                 tx4 = [q.taxon[4] for q in d.quartet],
                obsCF12=[q.obsCF[1] for q in d.quartet],
                obsCF13=[q.obsCF[2] for q in d.quartet],
                obsCF14=[q.obsCF[3] for q in d.quartet],
                expCF12=[q.qnet.expCF[1] for q in d.quartet],
                expCF13=[q.qnet.expCF[2] for q in d.quartet],
                expCF14=[q.qnet.expCF[3] for q in d.quartet])
   return df
end


# function to set nonidentifiable edges BL to -1.0
# used at the end of optTopRuns
function setNonIdBL!(net::HybridNetwork)
    for(e in net.edge)
        if(!e.istIdentifiable)
            e.length = -1.0 #do not use setLength because it does not allow BL too negative
        end
    end
end

# function that we need to overwrite to avoid printing useless scary
# output for HybridNetworks
# PROBLEM: writeTopology changes the network and thus show changes the network
function Base.show(io::IO, obj::HybridNetwork)
    disp = "$(typeof(obj)), "
    if obj.isRooted
        disp = disp * "Rooted Network"
    else
        disp = disp * "Un-rooted Network"
    end
    disp = disp * "\n$(obj.numEdges) edges\n"
    disp = disp * "$(obj.numNodes) nodes: $(obj.numTaxa) tips, "
    disp = disp * "$(obj.numHybrids) hybrid nodes, "
    disp = disp * "$(obj.numNodes - obj.numTaxa - obj.numHybrids) internal tree nodes.\n"
    tipslabels = [n.name for n in obj.leaf]
    if length(tipslabels) > 1 || !all(tipslabels .== "")
        disptipslabels = "$(tipslabels[1])"
        for i in 2:min(obj.numTaxa, 4)
            disptipslabels = disptipslabels * ", $(tipslabels[i])"
        end
        if obj.numTaxa > 4 disptipslabels = disptipslabels * ", ..." end
        disp *= "tip labels: " * disptipslabels
    end
    par = ""
    try
        # par = writeTopology(obj,round=true) # but writeTopology changes the network, not good
        s = IOBuffer()
        writeSubTree!(s, obj, false,true,false, true,3)
        par = bytestring(s)
    catch err
        println("ERROR with writeSubTree!: $(err)\nTrying writeTopologyLevel1")
        par = writeTopologyLevel1(obj)
    end
    disp *= "\n$par"
    println(io, disp)
end

# and QuartetNetworks (which cannot be just written because they do not have root)
function Base.show(io::IO, net::QuartetNetwork)
    print(io,"taxa: $(net.quartetTaxon)\n")
    print(io,"number of hybrid nodes: $(net.numHybrids)\n")
    if(net.split != [-1,-1,-1,-1])
        print(io,"split: $(net.split)\n")
    end
end

function Base.show(io::IO,d::DataCF)
    print(io,"Object DataCF\n")
    print(io,"number of quartets: $(d.numQuartets)\n")
    if(d.numTrees != -1)
        print(io,"number of trees: $(d.numTrees)\n")
    end
end

function Base.show(io::IO,q::Quartet)
    print(io,"number: $(q.number)\n")
    print(io,"taxon names: $(q.taxon)\n")
    print(io,"observed CF: $(q.obsCF)\n")
    print(io,"pseudo-deviance under last used network: $(q.logPseudoLik) (meaningless before estimation)\n")
    print(io,"expected CF under last used network: $(q.qnet.expCF) (meaningless before estimation)\n")
    if(q.ngenes != -1)
        print(io,"number of genes used to compute observed CF: $(q.ngenes)\n")
    end
end

function Base.show(io::IO, obj::Node)
    disp = "$(typeof(obj)):"
    disp = disp * "\n number:$(obj.number)"
    if (obj.name != "") disp *= "\n name:$(obj.name)" end
    if (obj.hybrid)     disp *= "\n hybrid node" end
    if (obj.leaf)       disp *= "\n leaf node" end
    disp *= "\n attached to $(length(obj.edge)) edges, numbered:"
    for (e in obj.edge) disp *= " $(e.number)"; end
    println(io, disp)
end

function Base.show(io::IO, obj::Edge)
    disp = "$(typeof(obj)):"
    disp *= "\n number:$(obj.number)"
    disp *= "\n length:$(obj.length)"
    if (obj.hybrid)
        disp *= "\n " * (obj.isMajor ? "major" : "minor")
        disp *= " hybrid edge with gamma=$(obj.gamma)"
    elseif (!obj.isMajor)
        disp *= "\n minor tree edge"
    end
    disp *= "\n attached to $(length(obj.node)) node(s) (parent first):"
    if (length(obj.node)==1) disp *= " $(obj.node[1].number)";
    elseif (length(obj.node)==2)
        disp *= " $(obj.node[obj.isChild1 ? 2 : 1].number)"
        disp *= " $(obj.node[obj.isChild1 ? 1 : 2].number)"
    end
    println(io, disp)
end

