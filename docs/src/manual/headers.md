# Headers

FITS files consist of one or more HDUs (header data units), and each HDU can contain an N-dimensional image or table.
Before the data is a *header*. Headers contain (key, value, comment) groups as well as dedicated long-form COMMENT and HISTORY sections used to document, for example, the series of post-processing steps applied to an image.

## Accessing Headers 

Here are some examples of how to set and read keys, comments, and history.

Well start by making a blank image.
```julia
img = AstroImage(zeros(10,10))
# Set keys to values with different data types
img["KEY1"] = 2   # Integer
img["KEY2"] = 2.0 # Float
img["KEY3"] = "STRING"
img["KEY4"] = true
img["KEY5"] = false
img["KEY6"] = nothing

# Set comments
img["KEY1", Comment] = "A key with an integer value"

# Read keys
a = img["KEY3"]

# Read comment
com = img["KEY1", Comment]

# Add long-form COMMENT
push!(img, Comment, """
We now describe how to add a long form comment to the end of a header.
""")

# Add HISTORY entry
push!(img, History, """
We now describe how to add a long form history to the end of a header.
""")

# Retrieve long form comments/ history
comment_strings = img[Comment]
history_strings = img[History]
```

Note that floating point values are formatted as ASCII strings when written to the FITS files, so the precision may be limited. 

`AstroImage` objects wrap a FITSIO.jl `FITSHeader`. If necessary, you can recover it using `header(img)`; however, in most cases you can access header keywords directly from the image.



API docs:
[`Comment`](@ref Comment)
[`History`](@ref History)
[`header`](@ref header)