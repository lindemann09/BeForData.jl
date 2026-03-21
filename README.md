# BeForData.jl

[![Julia](https://img.shields.io/badge/Julia-1.10%2B-blue)](https://julialang.org)
[![GitHub license](https://img.shields.io/github/license/lindemann09/befordata.jl)](https://github.com/lindemann09/befordata.jl/blob/master/LICENSE)
[![Build Status](https://github.com/lindemann09/BeForData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lindemann09/BeForData.jl/actions/workflows/CI.yml?query=branch%3Amain)

**BeForData** is a Julia package for working with behavioural response force data.
It provides two core data structures — `BeForRecord` for continuous recordings and
`BeForEpochs` for trial-based epoch data — together with tools for preprocessing,
epoch extraction, baseline correction, and file I/O.

**Documentation**: [https://lindemann09.github.io/BeForData.jl](https://lindemann09.github.io/BeForData.jl)

(c) 2024 Oliver Lindemann, Erasmus University Rotterdam


## Overview

Force platform recordings are typically collected as one long continuous signal,
sometimes spanning multiple experimental sessions or blocks. **BeForData** separates
this workflow into two stages:

1. **`BeForRecord`** – holds the raw, continuous time-series with one or more sessions,
   optional time stamps, and arbitrary metadata.
2. **`BeForEpochs`** – holds the segmented, trial-aligned force matrix extracted from a
   `BeForRecord`, along with an optional trial design table and baseline information.

Optional extensions add support for reading/writing [Apache Arrow](https://arrow.apache.org/)
(Feather) files, applying [DSP](https://github.com/JuliaDSP/DSP.jl) filters, and
loading [XDF](https://github.com/xdf-modules/xdf-Julia) streams.


## Installation

```julia
using Pkg
Pkg.add("BeForData")
```

Optional extension packages can be added independently:

```julia
Pkg.add("Arrow")   # file I/O
Pkg.add("DSP")     # filtering
Pkg.add("XDF")     # XDF stream loading
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Python

A [Python implementation](https://github.com/lindemann09/befordata) of **BeForData** is also available.
