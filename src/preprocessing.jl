"""
	scale_force!(fd::BeForRecord, factor::Real) -> BeForRecord
	scale_force!(fd::BeForEpochs, factor::Real) -> BeForEpochs

Multiply all force channel values by `factor` in place.

For `BeForRecord`, every column listed in `fd.force_cols` is scaled.
For `BeForEpochs`, the entire force matrix and the baseline vector (if present) are
scaled so that the baseline-corrected representation remains consistent.

Returns `fd` (mutated in place).

See also: [`detrend`](@ref), [`moving_average`](@ref)
"""
function scale_force!(fd::BeForRecord, factor::Real)
	return fd.dat[:, fd.force_cols] = fd.dat[:, fd.force_cols] .* factor
end

function scale_force!(fd::BeForEpochs, factor::Real)
	fd.dat[:, :] = fd.dat .* factor
	fd.baseline[:] = fd.baseline[:] .* factor
	return fd
end


"""
	moving_average(dat::AbstractVector{<:AbstractFloat}, window_size::Int) -> Vector

Compute a centred moving average of `dat` using a window of `window_size` samples.

Near the boundaries the window is clamped to the available data (no padding), so the
output has the same length as the input.

See also: [`moving_average(::BeForRecord, ::Int)`](@ref), [`detrend`](@ref)
"""
function moving_average(dat::AbstractVector{<:AbstractFloat},
	window_size::Int64)
	rtn = similar(dat)
	n = length(dat)
	lower = ceil(Int64, window_size / 2)
	upper = window_size - lower - 1
	for x in 1:n
		f = x - lower
		if f < 1
			f = 1
		end
		t = x + upper
		if t > n
			t = n
		end
		@inbounds rtn[x] = mean(dat[f:t])
	end
	return rtn
end

"""
	moving_average(d::BeForRecord, window_size::Int) -> BeForRecord

Apply a centred moving average with `window_size` samples to every force channel in
`d`, processing each session independently.

Returns a new `BeForRecord`; the original is not modified. The window size is recorded
in the metadata of the returned record.

See also: [`moving_average(::AbstractVector, ::Int)`](@ref), [`detrend`](@ref)
"""
function moving_average(d::BeForRecord, window_size::Int)

	df = copy(d.dat)
	for r in session_range(d)
		for c in d.force_cols
			df[r, c] = moving_average(df[r, c], window_size)
		end
	end
	meta = Dict("Moving average window: " => window_size)
	return BeForRecord(df, d.sampling_rate, d.time_column, d.sessions,
		merge(d.meta, meta))
end;


"""
	detrend(d::BeForRecord, window_size::Int) -> BeForRecord

Remove a slow trend from every force channel in `d` by subtracting a centred moving
average with `window_size` samples from the raw signal.

Each session is processed independently. Returns a new `BeForRecord`; the original is
not modified. The window size is recorded in the metadata of the returned record.

See also: [`moving_average`](@ref), [`scale_force!`](@ref)
"""
function detrend(d::BeForRecord, window_size::Int)

	df = copy(d.dat)
	for r in session_range(d)
		for c in d.force_cols
			@inbounds df[r, c] = df[r, c] .- moving_average(df[r, c], window_size)
		end
	end
	meta = Dict("Detrend window: " => window_size)
	return BeForRecord(df, d.sampling_rate, d.time_column, d.sessions,
		merge(d.meta, meta))
end;

"""
	detect_sessions() -> nothing

Automatically detect session boundaries in a recording.

!!! note
    Not yet implemented.
"""
function detect_sessions()
	# TODO
end

