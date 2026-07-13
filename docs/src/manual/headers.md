# Headers

```@setup 1
using AstroImages
```

FITS files consist of one or more HDUs (header data units), and each HDU can contain an N-dimensional image or table. Before the data is a *header*. Headers contain (key, value, comment) groups as well as dedicated long-form COMMENT and HISTORY sections used to document, for example, the series of post-processing steps applied to an image.

## Accessing Headers

Here are some examples of how to set and read keys, comments, and history.

We'll start by making a blank image:

```@example 1
img = AstroImage(zeros(10, 10))
```

Set keys to values with different data types:

```@example 1
img["KEY1"] = 2   # Integer
img["KEY2"] = 2.0 # Float
```

!!! note
    Floating point values are formatted as ASCII strings when written to the FITS files, so the precision may be limited.

``` @example 1
img["KEY3"] = "STRING"
img["KEY4"] = true
img["KEY5"] = false
img["KEY6"] = nothing # Undefined value
nothing # hide
```

!!! note
    A keyword may be present in a header with no value at all. Assigning `nothing` (or `missing`) creates such a card, and it reads back as `missing`:

    ```@example 1
    img["KEY6"]
    ```

    A key that is not present in the header instead reads back as `nothing`, so the two cases can be told apart:

    ```@example 1
    isnothing(img["KEY7"])
    ```


We can set comments:

```@example 1
img["KEY1", Comment] = "A key with an integer value";
nothing # hide
```

and view:

```@example 1
header(img)
```

Read keys:

```@example 1
a = img["KEY3"]
```

Read comment:

```@example 1
com = img["KEY1", Comment]
```

Add long-form COMMENT:

```@example 1
push!(img, Comment, """
We now describe how to
add a long form comment
to the end of a header.
""")

header(img)
```

Add HISTORY entry:

```@example 1
push!(img, History, """
We now describe how to
add a long form history
to the end of a header.
""")

header(img)
```

A COMMENT or HISTORY card stores its text in columns 9-80, so it can hold at most 72 characters and cannot contain a newline. Multi-line text is therefore split into one card per line, and any line too long to fit on a single card is wrapped across as many cards as it needs:

```@example 1
push!(img, Comment, """
This comment spans two lines, the second of which is long enough that it will not fit on a single card.
""")
header(img)
```

We can retrieve long form comments/history by indexing them directly:

```@example 1
comment_strings = img[Comment]
```

```@example 1
history_strings = img[History]
```

API docs:
- [`Comment`](@ref Comment)
- [`History`](@ref History)
- [`header`](@ref header)
