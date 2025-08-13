"""
	scale_force!(fd::BeForRecord, factor::Real)
	scale_force!(fd::BeForEpochs, factor::Real)

	TODO
"""
function scale_force!(fd::BeForRecord, factor::Real)
	idx = fd.force_cols
	fd.dat[:, idx] = fd.dat[:, idx] .* factor
	return fd
end

function scale_force!(fd::BeForEpochs, factor::Real)
	fd.dat[:, :] = fd.dat .* factor
	fd.baseline[:] = fd.baseline[:] .* factor
	return fd
end


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
	moving_average!(fd::BeForRecord; window_size::Int)

TODO
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
	detrend(d::BeForRecord; window_size::Int)

TODO
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

function detect_sessions()
	# TODO
end

