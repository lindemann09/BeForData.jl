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

## FILTER using DSP
function filtfilt_record(coef::FilterCoefficients, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(coef, rtn.dat[r, c])
		end
	end
	return rtn
end

function filtfilt_record(b::AbstractVector, a::AbstractVector, rec::BeForRecord)::BeForRecord

	rtn = copy(rec)
	for r in session_range(rtn)
		for c in rtn.force_cols
			rtn.dat[r, c] = filtfilt(b, a, rtn.dat[r, c])
		end
	end
	return rtn
end

function lowpass_filter(rec::BeForRecord;
	cutoff::Real,
	order::Integer)

	butter_flt = digitalfilter(Lowpass(cutoff), Butterworth(order);
		fs = rec.sampling_rate)
	rtn = filtfilt_record(butter_flt, rec)

	rtn.meta["filter"] = "butterworth: cutoff="*string(cutoff)*", order="*string(order)
	return rtn
end

function lowpass_filter(fe::BeForEpochs;
	cutoff::Real,
	order::Integer = 4,
	center_data::Bool = true,
	suppress_warning::Bool = false,
) # FIXME old method, maybe remove center_data
	suppress_warning || @warn "It's suggested to filter the data (i.e. BeForRecord) " *
							  "before creating epochs, because each epoch will be filter individually. " *
							  "This might causes artifacts"

	rtn = copy(fe)
	sampling_rate = rtn.sampling_rate
	for row in eachrow(rtn.dat)
		row[:] = lowpass_filter(vec(row);
			sampling_rate, cutoff, order, center_data)
	end
	return rtn
end;





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

