
abstract AbstractDataIterator{T,IB}
isbatches{T,IB}(iter::AbstractDataIterator{T,IB}) = IB


"""
    DataIterator(data, start, count)

Description
============

Allows to iterator over some `data`, either in single steps
if `indices` is an integer, or in batches, if `indices` is a range.

If used as an iterator, the object will iterate over the dataset once,
effectively denoting an epoch. Each iteration will return a
minibatch/observation of constant `nobs`, which can be specified using
keyword parameters.

The type is usually not constructed manually, but instead instantiated
by calling `eachobs`, or `eachbatch`

Arguments
==========

- **`data`** : The object describing the dataset. Can be of any
    type as long as it implements `getobs` and `nobs`.

- **`start`** : The index/indices of the first observation(s).
    Can be either of type `Int` or `UnitRange` and denotes

- **`count`** : The number of elements that the iterator will return.
    If `start` is an integer, this will denote the number of
    observations to return, otherwise the number of batches.

Details
========

For `DataIterator` to work on some data structure, the given variable
`data` must implement the following interface:

- `getobs(data, i)` : Should return the observation(s) indexed
    by `i`. In what form is up to the user.

- `nobs(data)` : Should return the number of observations in `data`

Author(s)
==========

- Christof Stocker (Github: https://github.com/Evizero)
- Tom Breloff (Github: https://github.com/tbreloff)

Examples
=========

```julia
X, Y = load_iris()

for x in eachobs(X)
    @assert typeof(x) <: SubArray{Float64,1}
end

# iterate over each individual labeled observation
for (x,y) in eachobs(X,Y)
    @assert typeof(x) <: SubArray{Float64,1}
    @assert typeof(y) <: String
end

# same but in random order
for (x,y) in eachobs(shuffled(X,Y))
    @assert typeof(x) <: SubArray{Float64,1}
    @assert typeof(y) <: String
end

# iterate over the first 2 batches of 15 observation each
# one can also just specify one or none of the keyword arguments
for (x,y) in eachbatch(X,Y, size=15, count=2)
    @assert typeof(x) <: SubArray{Float64,2}
    @assert typeof(y) <: SubArray{String,1}
    @assert size(x) == (4, 15)
    @assert size(y) == (15,)
end
```

see also
=========

`DataSubset`, `eachbatch`, `eachobs`, `shuffled`, `getobs`, `nobs`
"""
immutable DataIterator{T, S<:Union{Int,AbstractVector}, ISBATCHES} <: AbstractDataIterator{T,ISBATCHES}
    data::T
    start::S
    count::Int
end

DataIterator(data) = DataIterator(data, 1, nobs(data))
function DataIterator(data, start, count)
    DataIterator{typeof(data), typeof(start), isbatches(start)}(data,start,count)
end
# function DataIterator{T,S}(data::T, start::S = 1, count::Int = nobs(data))
#     R = typeof(datasubset(data,start))
#     DataIterator{T,S,R}(data,start,count)
# end


isbatches(::Int)                               = false # eachobs
isbatches(::UnitRange{Int})                    = true  # eachbatch
isbatches(::AbstractVector{Int})               = false # was: DataSubset
isbatches{S<:AbstractVector{Int}}(::Vector{S}) = true  # was: Vector{DataSubset}

# --------------------------------------------------------------------

# show_endstr(s::Int)                               = " observations" # eachobs
show_endstr(s::UnitRange{Int})                    = string(length(s), " obs each")  # eachbatch
# show_endstr(s::AbstractVector{Int})               = " observations" # was: DataSubset
show_endstr{S<:AbstractVector{Int}}(s::Vector{S}) = string("indices: ", s)  # was: Vector{DataSubset}

function Base.show(io::IO, iter::DataIterator)
    print(io, "DataIterator{", typeof(iter.data), "}: ", iter.count)
    if isbatches(iter)
        print(io, " batches with ", show_endstr(iter.start))
    else
        print(io, " observations")
    end
end

# Base.eltype{T,S,R}(::Type{DataIterator{T,S,R}}) = R

Base.length(iter::DataIterator) = iter.count
nobs(iter::DataIterator) = nobs(iter.data)

Base.endof(iter::DataIterator) = iter.count
Base.getindex(iter::DataIterator, batchindex) = viewobs(iter.data, (batchindex-1)*length(iter.start)+iter.start)
getobs(iter::DataIterator, batchindex) = getobs(iter.data, (batchindex-1)*length(iter.start)+iter.start)
getobs(iter::DataIterator) = getobs.(collect(iter))

# --------------------------------------------------------------------
# iteration

# eachobs
Base.start{T}(iter::DataIterator{T,Int}) = iter.start
Base.done{T}(iter::DataIterator{T,Int}, idx) = idx > iter.count
Base.next{T}(iter::DataIterator{T,Int}, idx) = (viewobs(iter.data, idx), idx + 1)

# eachbatch
Base.start{T}(iter::DataIterator{T,UnitRange{Int}}) = iter.start
Base.done{T}(iter::DataIterator{T,UnitRange{Int}}, idx) = maximum(idx) > iter.count * length(iter.start)
Base.next{T}(iter::DataIterator{T,UnitRange{Int}}, idx) = (viewobs(iter.data, idx), idx + length(iter.start))

# was: DataSubset
Base.start{T,S<:AbstractVector{Int}}(iter::DataIterator{T,S}) = 1
Base.done{T,S<:AbstractVector{Int}}(iter::DataIterator{T,S}, idx) = idx > iter.count
Base.next{T,S<:AbstractVector{Int}}(iter::DataIterator{T,S}, idx) = (viewobs(iter.data, iter.start[idx]), idx+1)

# was: Vector{DataSubset}
Base.start{T,S<:AbstractVector{Int}}(iter::DataIterator{T,Vector{S}}) = 1
Base.done{T,S<:AbstractVector{Int}}(iter::DataIterator{T,Vector{S}}, idx) = idx > iter.count
Base.next{T,S<:AbstractVector{Int}}(iter::DataIterator{T,Vector{S}}, idx) = (viewobs(iter.data, iter.start[idx]), idx+1)

# --------------------------------------------------------------------

"""
    eachobs(source[...])

Iterate over a data source using a `DataIterator`

```julia
for x in eachobs(X)
    # ...
end
```

Multiple variables are supported (e.g. for labeled data)

```julia
for (x,y) in eachobs(X,Y)
    # ...
end
```

see `DataIterator` for more info
"""
eachobs(source) = DataIterator(source, 1, nobs(source))

"""
    eachbatch(source[...]; [count], [size])

Iterate over a data source in `count` equally sized batches of
`size` by using a `DataIterator`.
In the case that the size of the dataset is not dividable by
the specified (or inferred) size, the remaining observations will
be ignored.

```julia
for x in eachbatch(X, count = 10)
    # code called 10 times
    # nobs(x) won't change over iterations
end
```

Multiple variables are supported (e.g. for labeled data)

```julia
for (x,y) in eachbatch(X, Y, size = 20)
    @assert nobs(x) == 20
    @assert nobs(y) == 20
    # ...
end
```

see `DataIterator` for more info
"""
function eachbatch(source; size::Int = -1, count::Int = -1)
    nsize, ncount = _compute_batch_settings(source, size, count)
    DataIterator(source, 1:nsize, ncount)
end

# ----------------------------------------------------------------

datasubset(data) = DataIterator(data)
datasubset(data, indices) = DataIterator(data, indices, length(indices))

# TODO:
#datasubset(iter::DataIterator, args...)

shuffled(data) = viewobs(data, shuffle(1:nobs(data)))

# ----------------------------------------------------------------
# infinite iterators

type InfiniteIterator{T,IB} <: AbstractDataIterator{T,IB}
    data::T
    func::Function
end

nobs(iter::InfiniteIterator) = nobs(iter.data)
Base.start(iter::InfiniteIterator) = 1
Base.done(iter::InfiniteIterator, idx) = false
Base.next(iter::InfiniteIterator, idx) = (iter.func(iter.data), 1)

function infinite_obs(data)
    InfiniteIterator{typeof(data),false}(data, data -> viewobs(data, rand(1:nobs(data))))
end

function infinite_batches(data; size=1)
    InfiniteIterator{typeof(data),true}(data, data -> viewobs(data, rand(1:nobs(data), size)))
end
