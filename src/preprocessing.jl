function scale_force!(d::BeForRecord, factor::Real)
	d.dat[!, d.force_cols] = d.dat[!, d.force_cols] .* factor
	return d
end

function lowpass_filter(dat::AbstractVector{<:AbstractFloat};
	sampling_rate::Real,
	cutoff::Real,
	butterworth_order::Integer,
	center_data::Bool = true
)
	myfilter = digitalfilter(Lowpass(cutoff), Butterworth(butterworth_order);
					fs = sampling_rate)
	if center_data
		return filtfilt(myfilter, dat .- dat[1]) .+ dat[1] # filter centred data
	else
		return filtfilt(myfilter, dat)
	end
end;

function lowpass_filter(d::BeForRecord;
	cutoff::Real,
	butterworth_order::Integer,
	center_data::Bool = true)

	df = copy(d.dat)
	sampling_rate = d.sampling_rate
	for r in session_samples(d)
		for c in d.force_cols
			df[r, c] = lowpass_filter(df[r, c]; sampling_rate,
				cutoff, butterworth_order, center_data)
		end
	end
	meta = Dict("cutoff" => cutoff,
		"butterworth_order" => butterworth_order)
	meta = merge(d.meta, meta)
	return BeForRecord(df, d.sampling_rate, d.time_column, d.sessions, meta)
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
	for r in session_samples(d)
		for c in d.force_cols
			df[r, c] = moving_average(df[r, c], window_size)
		end
	end
	meta =  Dict("Moving average window: " => window_size)
	return BeForRecord(df, d.sampling_rate, d.time_column, d.sessions,
                         merge(d.meta, meta))
end;


"""
	detrend(d::BeForRecord; window_size::Int)

TODO
"""
function detrend(d::BeForRecord, window_size::Int)

	df = copy(d.dat)
	for r in session_samples(d)
		for c in d.force_cols
			@inbounds df[r, c] = df[r, c] .- moving_average(df[r, c], window_size)
		end
	end
	meta =  Dict("Detrend window: " => window_size)
	return BeForRecord(df, d.sampling_rate, d.time_column, d.sessions,
                    merge(d.meta, meta))
end;



function detect_sessions()
	# TODO
end

