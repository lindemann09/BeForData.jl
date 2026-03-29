"""
	BeForRecord

Response force recording with optional multi-session support.

Fields
------
- `dat`: `DimArray` with dimensions `(time, name)` containing force data as
  `Float64`. The `time` dimension holds time stamps in ms; the `name` dimension
  holds channel names.
- `additional_dat`: `DataFrame` with any columns from the source data that are
  neither the time column nor force channels, or `nothing` if no such columns exist.
- `sampling_rate`: Sampling rate in Hz.
- `sessions`: 1-based sample indices that mark the start of each session. The first
  entry is always 1.
- `meta`: Arbitrary metadata stored as a string-keyed dictionary.

Computed properties (read-only)
--------------------------------
- `n_samples`: Total number of samples across all sessions.
- `n_forces`: Number of force channels.
- `time_column`: Name of the time dimension (a `Symbol`).
- `force_cols`: Vector of force channel names.

See also: [`BeForEpochs`](@ref), [`forces`](@ref), [`time_stamps`](@ref),
[`split_sessions`](@ref), [`extract_epochs`](@ref)
"""
struct BeForRecord
	dat::DimArray{Float64}
	additional_dat::Union{Nothing, DataFrame}
	sampling_rate::Float64
	sessions::Vector{Int}
	meta::Dict{String, Any}

	function BeForRecord(dat::DimArray,
		additional_dat::Union{Nothing, DataFrame},
		sampling_rate::Real,
		sessions::Union{Nothing, AbstractVector{Int}},
		meta::Dict{String, Any})

		if isnothing(sessions)
			sessions = size(dat, 1) > 0 ? [1] : Int[]
		else
		end
		if sessions[1] > 1
			pushfirst!(sessions, 1) # first session must be 1
		elseif sessions[1] < 1
			sessions[1] = 1
		end
		new(dat, additional_dat, sampling_rate, sessions, meta)
	end
end;

"""
	BeForRecord(dat::DimArray, [additional_dat::DataFrame,] sampling_rate::Real;
		sessions=nothing, meta=Dict{String, Any}())

Construct a `BeForRecord` from pre-built components.

Arguments
---------
- `dat`: `DimArray` with dimensions `(time, name)` containing force data.
- `additional_dat`: `DataFrame` with non-force columns (Optional)
- `sampling_rate`: Sampling rate in Hz.

Keyword Arguments
-----------------
- `sessions`: 1-based sample indices marking the start of each session.
  If `nothing` (default), a single session is inferred (`[1]` for non-empty data).
- `meta`: Metadata dictionary. Defaults to an empty dictionary.

See also: [`BeForRecord(::DataFrame, ...)`](@ref)
"""
BeForRecord(dat::DimArray, additional_dat::DataFrame, sampling_rate::Real;
	sessions::Union{Nothing, AbstractVector{Int}} = nothing, meta::Dict = Dict{String, Any}()) =
	BeForRecord(dat, additional_dat, sampling_rate, sessions, meta)
BeForRecord(dat::DimArray, sampling_rate::Real;
	sessions::Union{Nothing, AbstractVector{Int}} = nothing, meta::Dict = Dict{String, Any}()) =
	BeForRecord(dat, nothing, sampling_rate, sessions, meta)

"""
	BeForRecord(dat::DataFrame, sampling_rate::Real;
		force_cols=nothing, time_column=nothing, sessions=nothing, meta=Dict())

Construct a `BeForRecord` from a DataFrame.

Arguments
---------
- `dat`: Source DataFrame. Columns are partitioned into the time column, force
  channels, and any remaining columns stored in `additional_dat`.
- `sampling_rate`: Sampling rate in Hz.

Keyword Arguments
-----------------
- `force_cols`: Column name(s) to treat as force channels. Accepts a `String`,
  `Symbol`, or `AbstractVector` of names. If `nothing` (default), all columns
  except the time column are used.
- `time_column`: Name of the column holding time stamps in ms. If `nothing`
  (default), time stamps are generated from `sampling_rate` starting at 0 ms.
- `sessions`: 1-based sample indices marking the start of each session. Defaults to
  `[1]` (single session covering all samples).
- `meta`: Optional metadata dictionary.

Returns
-------
A `BeForRecord` where `forces` contains only the selected force columns and
`additional_dat` contains any remaining, non-time/non-force columns.
"""
function BeForRecord(dat::DataFrame,
	sampling_rate::Real;
	force_cols::Union{Nothing, Symbol, String, AbstractVector{String}, AbstractVector{Symbol}} = nothing,
	time_column::Union{Nothing, Symbol, String} = nothing,
	sessions::Union{Nothing, AbstractVector{Int}} = nothing,
	meta::Dict = Dict{String, Any}(),
)

	if isnothing(time_column)
		step = 1000.0 / sampling_rate # in ms
		final_time = (nrow(dat) - 1) * step
		time_stamps = 0:step:final_time
		used_columns = String[]
	else
		time_column = String(time_column)
		if time_column ∉ names(dat)
			throw(ArgumentError("'$time_column' not in dataframe"))
		end
		time_stamps = dat[:, time_column]
		used_columns = [time_column]
	end

	if force_cols isa String || force_cols isa Symbol
		force_cols = [String(force_cols)]
	elseif isnothing(force_cols)
		force_cols = filter!(x -> x != time_column, names(dat))
	end
	if time_column in force_cols
		throw(ArgumentError("time_column '$time_column' cannot be a force column"))
	end
	x = disallowmissing(dat[:, force_cols], error = false)
	forces = DimArray(Matrix(x), (time = time_stamps, name = names(x)))
	append!(used_columns, force_cols)

	additional_vars_names = setdiff(names(dat), used_columns)
	if length(additional_vars_names)>0
		additional_dat = dat[:, additional_vars_names]
	else
		additional_dat = nothing
	end

	return BeForRecord(forces, additional_dat, Float64(sampling_rate), sessions, meta)
end

"""
	copy(d::BeForRecord) -> BeForRecord

Return a deep copy of `d`, including copies of the underlying DataFrame, session
indices, and metadata dictionary.
"""
function Base.copy(d::BeForRecord)
	return BeForRecord(copy(d.dat), copy(d.additional_dat), d.sampling_rate,
		copy(d.sessions), copy(d.meta))
end

Base.propertynames(::BeForRecord) = (:forces, :additional_dat, :sampling_rate, :sessions, :meta,
	:time_column, :n_samples, :n_forces, :force_cols)
function Base.getproperty(d::BeForRecord, s::Symbol)
	if s === :n_samples
		return size(d.dat)[1]
	elseif s === :n_forces
		return size(d.dat)[2]
	elseif s === :time_column
		return name(dims(d.dat, 1))
	elseif s === :force_cols
		return collect(dims(d.dat, 2).val)
	else
		return getfield(d, s)
	end
end

"""
	split_sessions(d::BeForRecord) -> Vector{BeForRecord}

Split a multi-session `BeForRecord` into a vector of single-session records.

Each returned record contains only the samples belonging to one session. Metadata
is shared (not deep-copied) across the resulting records.

See also: [`session_range`](@ref), [`add_session`](@ref)
"""
function split_sessions(d::BeForRecord)
	rtn = BeForRecord[]
	for idx in session_range(d)
		dat = BeForRecord(d.dat[idx, :], d.additional_dat[idx, :], d.sampling_rate; meta= d.meta)
		push!(rtn, dat)
	end
	return rtn
end

"""
	time_stamps(d::BeForRecord; session=nothing) -> AbstractVector

Return the time stamps for `d` in milliseconds.

If `d` has a `time_column`, the values from that column are returned directly.
Otherwise, an evenly-spaced range starting at 0 ms is generated from `sampling_rate`.

Arguments
---------
- `session`: If an integer, return time stamps only for that session (1-based index).
  If `nothing` (default), return time stamps for all samples.

See also: [`session_range`](@ref), [`forces`](@ref)
"""
function time_stamps(d::BeForRecord; session::Union{Nothing, Int} = nothing)

	t = dims(d.dat, 1)
	if isnothing(session)
		return t
	else
		idx = session_range(d, session)
		return t[idx]
	end
end

"""
	forces(d::BeForRecord, [name::Union{Symbol, String}]; session=nothing) -> DimArray

Return the force data from `d` as a `DimArray`.

Keyword Arguments
-----------------
- `name`: Force channel name (`Symbol` or `String`) to select a single channel.
  If `nothing` (default), all channels are returned.
- `session`: 1-based session index. If `nothing` (default), data for all sessions
  is returned.

See also: [`time_stamps`](@ref), [`session_range`](@ref), [`BeForRecord`](@ref)
"""
forces(d::BeForRecord, name::Symbol; session::Union{Nothing, Int} = nothing) =
	forces(d, string(name); session)
forces(d::BeForRecord, name::String; session::Union{Nothing, Int} = nothing) =
	forces(d; session)[:, At(name)]
forces(d::BeForRecord, idx::Int; session::Union{Nothing, Int} = nothing) =
	forces(d; session)[:, idx]
function forces(d::BeForRecord;	session::Union{Nothing, Int} = nothing)
	if isnothing(session)
		return d.dat
	else
		return d.dat[session_range(d, session), :]
	end
end

"""
	add_session(d::BeForRecord, session_data::BeForRecord) -> BeForRecord
	add_session(d::BeForRecord, session_data::DataFrame) -> BeForRecord

Return a new `BeForRecord` with `session_data` appended as an additional session.

The new session begins at the sample immediately following the last sample of `d`.
`session_data` must have the same force channels as `d`.

Keyword Arguments
-----------------
- `reset_timestamps`: If `false` (default), absolute time stamps are preserved and
	concatenation requires that appended time stamps remain ordered. If `true`, the
	appended session keeps its own local time axis and is concatenated along the
	`time` dimension.

See also: [`split_sessions`](@ref), [`session_range`](@ref)
"""
function add_session(d::BeForRecord, session_data::DataFrame; reset_timestamps::Bool = false)
	bfr = BeForRecord(session_data, d.sampling_rate;
		force_cols = d.force_cols, time_column = d.time_column, meta = d.meta)
	return add_session(d, bfr; reset_timestamps)
end

function add_session(d::BeForRecord, session_data::BeForRecord; reset_timestamps::Bool = false)

	if reset_timestamps
		forces = cat(d.dat, session_data.dat; dims = Dim{:time}())
	else
		forces = vcat(d.dat, session_data.dat)
	end
	if forces isa Matrix
		throw(ArgumentError("Incompatible times stamps, time stamps must be ordered"))
	end
	adf = vcat(d.additional_dat, session_data.additional_dat)
	sessions = vcat(d.sessions, d.n_samples+1)
	return BeForRecord(forces, adf, d.sampling_rate, sessions, d.meta)
end

"""
	session_range(d::BeForRecord, session::Int) -> UnitRange{Int}
	session_range(d::BeForRecord) -> Vector{UnitRange{Int}}

Return the sample index range for the given session (1-based), or a vector of
ranges for all sessions when called without a session argument.

The range covers all samples from the session's start up to and including the last
sample before the next session (or the end of the record for the last session).

See also: [`split_sessions`](@ref), [`forces`](@ref), [`time_stamps`](@ref)
"""
function session_range(d::BeForRecord, session::Int)
	t = (session + 1) > length(d.sessions) ? d.n_samples : d.sessions[session+1]-1
	return d.sessions[session]:t
end

session_range(d::BeForRecord) = [session_range(d, s) for s in 1:length(d.sessions)]


"""
	find_samples_by_time(times::AbstractVector, d::BeForRecord) -> Vector{Int}

Return the sample indices in `d` that correspond to the given `times` (in ms).

For each value in `times`, the index of the first time stamp that is greater than or
equal to that value is returned. If no exact match exists, the next larger time stamp
is used:

```math
\\text{time\\_stamps}[i-1] \\leq t < \\text{time\\_stamps}[i]
```

If a value is larger than the final time stamp, the returned index is
`d.n_samples + 1`.

See also: [`time_stamps`](@ref), [`extract_epochs`](@ref)
"""
function find_samples_by_time(times::AbstractVector, d::BeForRecord)
	ts = time_stamps(d)
	return searchsortedfirst.(Ref(ts), times)
end;

function Base.show(io::IO, mime::MIME"text/plain", x::BeForRecord)
	println(io, "BeForRecord")
	println(io, "  sampling_rate: $(x.sampling_rate), n sessions: $(length(x.sessions)) ")
	println(io, "  time_column $(x.time_column)")
	println(io, "  metadata")
	for (k, v) in x.meta
		println(io, "  - $k: $v")
	end
	show(io, mime, x.dat)
end



