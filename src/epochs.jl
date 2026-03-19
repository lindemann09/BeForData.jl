"""
	BeForEpochs

Epoch-based response force data, where each epoch is a fixed-length segment of force
samples extracted from a continuous recording.

The data are stored as a 2-D matrix with shape `(n_epochs, n_samples)`.  An optional
`baseline` vector (one value per epoch) records the per-epoch mean that was subtracted
during baseline correction.

Fields
------
- `dat`: `(n_epochs × n_samples)` matrix of force values in `Float64`.
- `sampling_rate`: Sampling rate in Hz.
- `design`: DataFrame with one row per epoch holding trial-level metadata
  (condition labels, participant ID, etc.). May be empty.
- `baseline`: Per-epoch baseline values subtracted during [`adjust_baseline!`](@ref).
  Empty when no baseline correction has been applied.
- `zero_sample`: 1-based column index in `dat` that corresponds to the epoch's time
  zero (i.e. the triggering event).
- `meta`: Arbitrary metadata stored as a string-keyed dictionary.

Computed properties (read-only)
--------------------------------
- `n_epochs`: Number of epochs (rows of `dat`).
- `n_samples`: Number of samples per epoch (columns of `dat`).
- `is_baseline_adjusted`: `true` if a baseline correction has been applied.

See also: [`BeForRecord`](@ref), [`extract_epochs`](@ref), [`adjust_baseline!`](@ref),
[`subset`](@ref)
"""

struct BeForEpochs
	dat::Matrix{Float64}
	sampling_rate::Real
	design::DataFrame
	baseline::Vector{Float64}
	zero_sample::Int
	meta::Dict{String, Any}

	function BeForEpochs(dat::Matrix{Float64},
		sampling_rate::Real,
		design::DataFrame,
		baseline::Vector{Float64},
		zero_sample::Int,
		meta::Dict{String, Any})
		lf = size(dat, 1)
		lb = length(baseline)
		lb == 0 || lf == lb || throw(
			ArgumentError(
				"If base is defined, number of rows of force ($(lf)) must match the length of baseline ($(lb)).",
			),
		)
		n = nrow(design)
		n == 0 || lf == n || throw(
			ArgumentError(
				"Number of rows of force ($(lf)) must match the number of rows ins the design ($(n)).",
			),
		)
		return new(dat, sampling_rate, design, baseline, zero_sample, meta)
	end
end;

"""
	BeForEpochs(force::Matrix{Float64}, sampling_rate::Real;
		design=nothing, baseline=nothing, zero_sample=1, meta=nothing)

Construct a `BeForEpochs` from a force matrix.

Arguments
---------
- `force`: `(n_epochs × n_samples)` matrix of force values.
- `sampling_rate`: Sampling rate in Hz.

Keyword Arguments
-----------------
- `design`: DataFrame with one row per epoch containing trial metadata. Defaults to
  an empty DataFrame.
- `baseline`: Per-epoch baseline values (length must equal `n_epochs`). Defaults to
  an empty vector (no baseline correction applied).
- `zero_sample`: 1-based column index in `force` corresponding to time zero.
  Defaults to 1.
- `meta`: Metadata dictionary. Defaults to an empty dictionary.
"""
function BeForEpochs(force::Matrix{Float64},
	sampling_rate::Real;
	design::Union{Nothing, DataFrame} = nothing,
	baseline::Union{Nothing, Vector{Float64}} = nothing,
	zero_sample::Int = 1,
	meta::Union{Nothing,Dict{String, Any}} = nothing)
	if isnothing(baseline)
		baseline = Float64[]
	end
	if isnothing(design)
		design = DataFrame()
	end
	if isnothing(meta)
		meta = Dict{String, Any}()
	end
	return BeForEpochs(force, sampling_rate, design,
		baseline, zero_sample, meta)

end


Base.propertynames(::BeForEpochs) = (:dat, :sampling_rate, :design, :baseline,
	:zero_sample, :n_samples, :meta, :n_epochs, :is_baseline_adjusted)
function Base.getproperty(x::BeForEpochs, s::Symbol)
	if s === :n_epochs
		return size(x.dat, 1)
	elseif s === :is_baseline_adjusted
		return length(x.baseline) > 0
	elseif s === :n_samples
		return size(x.dat, 2)
	else
		return getfield(x, s)
	end
end

"""
	copy(fe::BeForEpochs) -> BeForEpochs

Return a deep copy of `fe`, including copies of the force matrix, design DataFrame,
baseline vector, and metadata dictionary.
"""
function Base.copy(fe::BeForEpochs)
	return BeForEpochs(copy(fe.dat), fe.sampling_rate, copy(fe.design),
		copy(fe.baseline), fe.zero_sample, copy(fe.meta))
end

function Base.show(io::IO, mime::MIME"text/plain", x::BeForEpochs)
	txt = "BeForEpochs"
	if length(x.baseline) > 0
		txt *= " (baseline adjusted)"
	end
	print(io, txt)
	println(io, "  $(x.n_epochs) epochs")
	println(io, "  $(x.n_samples) samples, sampling rate: $(x.sampling_rate), zero sample: $(x.zero_sample)")
	println(io, "  metadata")
	for (k, v) in x.meta
		println(io, "  - $k: $v")
	end
	if nrow(x.design) > 0
		print(io, "  Design: $(names(x.design))")
	else
		print(io, "  No design information")
	end
end

"""
	forces(d::BeForEpochs) -> Matrix{Float64}

Return the raw force matrix of `d` with shape `(n_epochs, n_samples)`.

See also: [`forces(::BeForRecord)`](@ref), [`adjust_baseline!`](@ref)
"""
forces(d::BeForEpochs) = d.dat

## processing
"""
	extract_epochs(d::BeForRecord, column;
		zero_samples=nothing, zero_times=nothing,
		n_samples, n_samples_before=0,
		design=nothing, suppress_warnings=false) -> BeForEpochs

Extract fixed-length epochs from a continuous `BeForRecord`.

Exactly one of `zero_samples` or `zero_times` must be provided to define the epoch
onset positions.

Arguments
---------
- `d`: Source `BeForRecord`.
- `column`: Column name (`Symbol`, `String`) or integer index of the force channel
  to extract.

Keyword Arguments
-----------------
- `zero_samples`: Integer sample indices (1-based) at which each epoch starts at
  time zero.
- `zero_times`: Time values (in ms) corresponding to the epoch time zero. These are
  converted to sample indices via [`find_samples_by_time`](@ref).
- `n_samples`: Number of samples to extract *after* (and including) the zero sample.
- `n_samples_before`: Number of samples to extract *before* the zero sample.
  Defaults to 0. The zero sample in the returned `BeForEpochs` is
  `n_samples_before + 1`.
- `design`: Optional DataFrame with one row per epoch containing trial metadata.
- `suppress_warnings`: If `true`, suppress warnings about incomplete epochs that
  extend beyond the end of the recording (missing samples are zero-padded).
  Defaults to `false`.

Returns
-------
A `BeForEpochs` with `length(zero_samples)` rows and
`n_samples_before + n_samples` columns.

See also: [`BeForEpochs`](@ref), [`adjust_baseline!`](@ref),
[`find_samples_by_time`](@ref)
"""
function extract_epochs(d::BeForRecord,
	column::Union{Symbol, String, Int};
	zero_samples::Union{Nothing, AbstractVector{<:Integer}} = nothing,
	zero_times::Union{Nothing, AbstractVector{<:Real}} = nothing,
	n_samples::Integer,
	n_samples_before::Integer,
	design::Union{Nothing, DataFrame} = nothing,
	suppress_warnings::Bool = false,
)
	(isnothing(zero_samples) && isnothing(zero_times)) && throw(
		ArgumentError("Define either the samples or times where to extract the epochs " *
					  "(i.e. parameter zero_samples or zero_time)"))

	(isnothing(zero_samples) != isnothing(zero_times)) || throw(
		ArgumentError("Define only one the samples or times where to extract the epochs, " *
					  "not both."))

	if !isnothing(zero_times)
		ts = time_stamps(d)
		zero_samples = [_find_larger_or_equal(zt, ts) for zt in zero_times]
		return extract_epochs(d, column; zero_samples, n_samples,
			n_samples_before, design, suppress_warnings)
	end

	dat = d.dat[:, column]
	samples_fd = d.n_samples # samples for data
	n_epochs = length(zero_samples)
	ncol = n_samples_before + n_samples
	force_mtx = Matrix{Float64}(undef, n_epochs, ncol)
	for (r, sz) in enumerate(zero_samples)
		from = sz - n_samples_before
		if from < samples_fd
			to = sz + n_samples - 1
			if to > samples_fd
				suppress_warnings && @warn "extract epochs: force epoch " * string(r) *
										   " is incomplete, " * string(to - samples_fd) *
										   " samples missing."
				force_mtx[r, :] .= vcat(dat[from:samples_fd], zeros(Float64, to - samples_fd))
			else
				force_mtx[r, :] .= dat[from:to]
			end
		end
	end

	if isnothing(design)
		design = DataFrame()
	end
	meta = Dict{String, Any}("record meta" => copy(d.meta))

	return BeForEpochs(force_mtx, d.sampling_rate, copy(design),
		Float64[], n_samples_before + 1, meta)
end;

"""
	adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer}) -> BeForEpochs

Subtract a per-epoch baseline from the force data in-place.

The baseline for each epoch is computed as the mean of the samples in
`baseline_window` (column indices into `d.dat`). If a previous baseline correction
has already been applied, the original (uncorrected) data are first restored before
recomputing the new baseline.

The per-epoch baseline values are stored in `d.baseline` so the correction can be
undone or tracked.

Returns `d` (mutated in place).

See also: [`extract_epochs`](@ref), [`BeForEpochs`](@ref)
"""
function adjust_baseline!(d::BeForEpochs, baseline_window::UnitRange{<:Integer})
	if length(d.baseline) > 0
		dat = d.dat .+ d.baseline
	else
		dat = d.dat
	end
	bsl = mean(dat[:, baseline_window], dims = 2)
	d.dat[:, :] .= dat .- bsl
	if length(d.baseline) > 0
		d.baseline[:] .= bsl
	else
		append!(d.baseline, bsl)
	end
	return d
end

"""
	vcat(d::BeForEpochs, other::BeForEpochs) -> BeForEpochs

Concatenate two `BeForEpochs` objects along the epoch dimension.

Both objects must have matching `n_samples`, `sampling_rate`, `zero_sample`, baseline
adjustment state, and design column names. The metadata of `d` (the first argument)
is used for the result; the metadata of `other` is discarded.

See also: [`subset`](@ref)
"""
function Base.vcat(d::BeForEpochs, other::BeForEpochs)

	if other.n_samples != d.n_samples
		throw(ArgumentError("Number of samples per epoch must match (got $(d.n_samples) and $(other.n_samples))."))
	end
	if other.sampling_rate != d.sampling_rate
		throw(ArgumentError("Sampling rates must match (got $(d.sampling_rate) and $(other.sampling_rate))."))
	end
	if other.zero_sample != d.zero_sample
		throw(ArgumentError("Zero sample indices must match (got $(d.zero_sample) and $(other.zero_sample))."))
	end
	if other.is_baseline_adjusted != d.is_baseline_adjusted
		throw(ArgumentError("One data structure is baseline adjusted, the other not."))
	end
	if any(names(other.design) .!= names(d.design))
		throw(ArgumentError("Design column names are not the same."))
	end
	baseline = vcat(d.baseline, other.baseline)
	design = vcat(d.design, other.design)
	return BeForEpochs(vcat(d.dat, other.dat), d.sampling_rate; design,
		baseline, zero_sample=d.zero_sample, meta=d.meta)
end


"""
	subset(fe::BeForEpochs, rows) -> BeForEpochs
	subset(fe::BeForEpochs, args...) -> BeForEpochs

Return a subset of `fe` containing only the selected epochs.

**Row-index form** – `rows` is a vector or tuple of integer indices (1-based) specifying
which epochs to keep.

**DataFrames form** – `args...` are passed directly to `DataFrames.subset` applied to
`fe.design`. Epochs whose design rows satisfy the condition are retained. Requires
`fe.design` to be non-empty.

Both forms copy the relevant slice of `fe.dat`, the `baseline` vector, and the design
DataFrame.

See also: [`vcat`](@ref), [`extract_epochs`](@ref)
"""
function DataFrames.subset(fe::BeForEpochs, rows::Base.AbstractVecOrTuple{Integer})
	force = fe.dat[rows, :]
	if length(fe.baseline) > 0
		bsln = fe.baseline[rows]
	else
		bsln = copy(fe.baseline)
	end
	subset_design = fe.design[rows, :]
	return BeForEpochs(force, fe.sampling_rate; design=subset_design,
		baseline=bsln, zero_sample=fe.zero_sample, meta=copy(fe.meta))
end

function DataFrames.subset(fe::BeForEpochs, args...)
	df = copy(fe.design)
	df.row_xxx .= 1:nrow(df)
	df = subset(df, args...)
	return subset(fe, df[:, :row_xxx])
end

### helper functions
"""
	_find_larger_or_equal(needle::Real, sorted_array::AbstractVector{<:Real}) -> Union{Int, Nothing}

Return the index of the first element in `sorted_array` that is greater than or equal
to `needle`. If no such element exists, return `nothing`.

```math
\\text{sorted\\_array}[i-1] < \\text{needle} \\leq \\text{sorted\\_array}[i]
```

This is a linear-scan fallback for non-standard array types; use
`searchsortedfirst` for plain vectors.
"""
function _find_larger_or_equal(needle::Real, sorted_array::AbstractVector{<:Real})
	cnt::Int = 0
	for x in sorted_array
		cnt = cnt + 1
		if x >= needle
			return cnt
		end
	end
	return nothing
end;
