module XdfExt

using DataFrames
using BeForData
using XDF
using EzXML

export xdf_data, xdf_channel_info

XDFStreams = Dict{Int, Any}

const TIME_STAMPS = "time_stamps"

_get_channel_id(::XDFStreams, channel::Int) = channel
function _get_channel_id(streams::XDFStreams, channel::AbstractString)
    for (i, s) in streams
        s["name"] == channel && return i
    end
    throw(ArgumentError("Can't find channel $(channel)"))
end

function BeForData.xdf_channel_info(streams::XDFStreams, channel::Union{Int, AbstractString})
    i = _get_channel_id(streams, channel)
    fields = ("name", "type", "nchannels", "dtype", "clock", "offset")
    return Dict(k => streams[i][k] for k in fields)
end

function _channel_labels(streams::XDFStreams, channel::Union{Int, AbstractString})
    i = _get_channel_id(streams, channel)
    xml_header = parsexml(streams[i]["header"])
    rtn = nodecontent.(findall("//desc//channel//label", root(xml_header)))
    if length(rtn) == 0
        return streams[i]["name"]
    else
        return rtn
    end
end

function BeForData.xdf_data(streams::XDFStreams, channel::Union{Int, AbstractString})
    i = _get_channel_id(streams, channel)
    lbs = append!([TIME_STAMPS], _channel_labels(streams, i))
    dat = hcat(streams[i]["time"], streams[i]["data"])
    return DataFrame(dat, lbs)
end

function BeForData.BeForRecord(streams::XDFStreams,
            channel::Union{Int, AbstractString},
			sampling_rate::Real; kwargs...)
    i = _get_channel_id(streams, channel)
    return BeForRecord(xdf_data(streams, i), sampling_rate;
        time_column = TIME_STAMPS,
		meta = xdf_channel_info(streams, i), kwargs...)
end


end # module