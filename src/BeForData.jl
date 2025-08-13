module BeForData

using Statistics: mean
using DataFrames
using DSP

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
        adjust_baseline!

export scale_force!,
        lowpass_filter,
        filtfilt_record,
        moving_average,
        detrend,
        detect_sessions

include("record.jl")
include("epochs.jl")
include("preprocessing.jl")

## Arrow support (requires Arrow)
function write_feather end
export write_feather

## XDF support (requires XDF and EzXML)
function xdf_data end
function xdf_channel_info end
export xdf_data, xdf_channel_info


end
