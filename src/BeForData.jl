module BeForData

using Statistics: mean
using DataFrames

export BeForRecord,
	forces,
	time_stamps,
	split_sessions,
	session_range,
	add_session,
	find_samples_by_time

export BeForEpochs,
	vcat,
	extract_epochs,
	adjust_baseline!,
	subset

export scale_force!,
	detect_sessions,
	moving_average,
	detrend

include("record.jl")
include("epochs.jl")
include("preprocessing.jl")


## Filtering support (requires DSP)
function filtfilt_record end
function lowpass_filter end
export filtfilt_record, lowpass_filter

## Arrow support (requires Arrow)
function write_feather end
export write_feather

## XDF support (requires XDF)
function xdf_data end
function xdf_channel_info end
export xdf_data, xdf_channel_info


end
