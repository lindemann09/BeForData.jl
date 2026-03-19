module XdfExt

using DataFrames
using BeForData
using XDF
using EzXML

export xdf_data, xdf_channel_info

XDFStreams = Dict{Int, Any}

const TIME_STAMPS = "time_stamps"

"""
	_get_channel_id(streams::XDFStreams, channel::Union{Int, AbstractString}) -> Int

Resolve `channel` to an integer stream key in `streams`.

If `channel` is already an `Int` it is returned unchanged. If it is a string, the
streams dict is searched for a stream whose `"name"` field matches; an
`ArgumentError` is thrown when no match is found.
"""
_get_channel_id(::XDFStreams, channel::Int) = channel
function _get_channel_id(streams::XDFStreams, channel::AbstractString)
    for (i, s) in streams
        s["name"] == channel && return i
    end
    throw(ArgumentError("Can't find channel $(channel)"))
end

"""
	xdf_channel_info(streams::XDFStreams, channel::Union{Int, AbstractString}) -> Dict

Return a metadata dictionary for the specified channel in `streams`.

The returned dictionary contains the fields `"name"`, `"type"`, `"nchannels"`,
`"dtype"`, `"clock"`, and `"offset"` extracted directly from the XDF stream.

See also: [`xdf_data`](@ref), [`BeForRecord(::XDFStreams, ...)`](@ref)
"""
function BeForData.xdf_channel_info(streams::XDFStreams, channel::Union{Int, AbstractString})
    i = _get_channel_id(streams, channel)
    fields = ("name", "type", "nchannels", "dtype", "clock", "offset")
    return Dict(k => streams[i][k] for k in fields)
end

"""
	_channel_labels(streams::XDFStreams, channel) -> Union{String, Vector{String}}

Return the channel labels for `channel` parsed from the XDF XML header.

If no `<label>` elements are found in the header, the stream name is returned as a
single string. Otherwise a vector of label strings is returned.
"""
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

"""
	xdf_data(streams::XDFStreams, channel::Union{Int, AbstractString}) -> DataFrame

Return the time-series data for `channel` as a DataFrame.

The first column is `"time_stamps"` and the remaining columns are named according to
the channel labels found in the XDF stream header. If no labels are defined, the
stream name is used as the single data column.

See also: [`xdf_channel_info`](@ref), [`BeForRecord(::XDFStreams, ...)`](@ref)
"""
function BeForData.xdf_data(streams::XDFStreams, channel::Union{Int, AbstractString})
    i = _get_channel_id(streams, channel)
    lbs = append!([TIME_STAMPS], _channel_labels(streams, i))
    dat = hcat(streams[i]["time"], streams[i]["data"])
    return DataFrame(dat, lbs)
end

"""
	BeForRecord(streams::XDFStreams, channel, sampling_rate::Real; kwargs...) -> BeForRecord

Construct a `BeForRecord` directly from an XDF stream.

The time stamps and force data for `channel` are extracted via [`xdf_data`](@ref) and
channel metadata is stored via [`xdf_channel_info`](@ref). Additional keyword
arguments are forwarded to the `BeForRecord` constructor.

See also: [`xdf_data`](@ref), [`xdf_channel_info`](@ref)
"""
function BeForData.BeForRecord(streams::XDFStreams,
            channel::Union{Int, AbstractString},
			sampling_rate::Real; kwargs...)
    i = _get_channel_id(streams, channel)
    return BeForRecord(xdf_data(streams, i), sampling_rate;
        time_column = TIME_STAMPS,
		meta = xdf_channel_info(streams, i), kwargs...)
end


end # module
