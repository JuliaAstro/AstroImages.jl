using Statistics


MAX_REJECT = 0.5
MIN_NPIXELS = 5
GOOD_PIXEL = 0
BAD_PIXEL = 1
KREJ = 2.5
MAX_ITERATIONS = 5


function flatten(image)

    # colapses into one dimension (Float64) a 2D array in row-major (C-style flattening)

    rows = size(image)[1]
    cols = size(image)[2]
    n_pxls = rows * cols

    result = Array{Float64}(undef, n_pxls)
    
    k = 1
    for i in 1:rows, j in 1:cols
        result[k] = image[i, j]
        k += 1
    end

    return result
end


function zsc_sample(image, maxpix)

    # Figure out which pixels to use for the zscale algorithm
    # Returns the 1-d array samples
    # Sample in a square grid, and return the first maxpix in the sample

    nc = size(image)[1]
    nl = size(image)[2]

    stride = maximum([1.0, sqrt((nc - 1) * (nl - 1) / maxpix)])
    stride = Int128(round(stride))

    samples = flatten(image[1:stride:end, 1:stride:end])
    
    return samples[1:maxpix]
end


function zsc_compute_sigma(flat, badpix)

    # Compute the rms deviation from the mean of a flattened array.
    # Ignore rejected pixels

    # Accumulate sum and sum of squares
    npix = length(badpix)
    sumz = 0
    sumsq = 0
    ngoodpix = 0
    for i in 1:npix
        if badpix[i] == GOOD_PIXEL
            sumz += flat[i]
            sumsq += flat[i] * flat[i]
            ngoodpix += 1
        end
    end

    # calculate mean and sigma
    if ngoodpix == 0
        mean = nothing
        sigma = nothing
    elseif ngoodpix == 1
        mean = sumz
        sigma = nothing
    else
        mean = sumz / ngoodpix
        temp = sumsq / (ngoodpix - 1) - sumz * sumz / (ngoodpix * (ngoodpix - 1))
        if temp < 0
            sigma = 0.0
        else
            sigma = sqrt(temp)
        end
    end

    return ngoodpix, mean, sigma
end


function convolve_same(arr1, arr2)

    # calculate full convolution and return first n values, where n is the size of larger input

    n1 = length(arr1)
    n2 = length(arr2)
    nfull = n1 + n2 - 1

    final = zeros(Float64, nfull)

    for i in 1:nfull, j in 1:i
        if (j <= n1) && (i + 1 - j <= n2)
            final[i] += arr1[j] * arr2[i + 1 - j]
        end
    end

    upper = maximum([n1, n2])
    return final[1:upper]
end


function zsc_fit_line(samples, npix, krej, ngrow, maxiter)

    # calculate slope and intercept for the algorithm

    # remapping indices from -1 to 1 inclusive
    xscale = 2 / (npix - 1)
    x = collect(0:(npix - 1))
    xnorm = x * xscale .- 1

    ngoodpix = npix
    minpix = maximum([MIN_NPIXELS, Int128(npix * MAX_REJECT)])
    last_ngoodpix = npix + 1

    # This is the mask used in k-sigma clipping. 0 is good, 1 is bad
    badpix = zeros(Int128, npix)

    # Iterate
    for niter in 1:maxiter
        if (ngoodpix >= last_ngoodpix) || (ngoodpix < minpix)
            break
        end

        # Accumulate sums to calculate straight line fit
        sumx = 0
        sumxx = 0
        sumy = 0
        sumxy = 0
        sum = 0
        for i in 1:length(badpix)
            if badpix[i] == GOOD_PIXEL
                sumx += xnorm[i]
                sumxx += xnorm[i] * xnorm[i]
                sumy += samples[i]
                sumxy += sample[i] * xnorm[i]
                sum += 1
            end
        end

        delta = (sum * sumxx) - (sumx * sumx)
        # Slope and intercept
        intercept = ((sumxx * sumy) - (sumx * sumxy)) / delta
        slope = ((sum * sumxy) - (sumx * sumy)) / delta

        # Subtract fitted line from the data array
        fitted = xnorm * slope + intercept
        flat = samples - fitted

        # Compute the k-sigma rejection threshold
        ngoodpix, mean, sigma = zsc_compute_sigma(flat, badpix, npix)

        threshold = sigma * krej

        # Detect and reject pixels further than k*sigma from the fitted line
        lcut = -threshold
        hcut = threshold

        for i in 1:npix
            if (flat[i] < lcut) || (flat[i] > hcut)
                badpix[i] = BAD_PIXEL
            end
        end
        
        # Convolve with a kernel of length ngrow
        kernel = zeros(Int128, ngrow) .+ 1
        badpix = convolve_same(badpix, kernel)

        ngoodpix = 0
        for i in 1:length(badpix)
            if badpix[i] == GOOD_PIXEL
                ngoodpix += 1
            end
        end
    end

    # Transform the line coefficients back to the X range [0:npix-1]
    zstart = intercept - slope
    zslope = slope * xscale

    return ngoodpix, zstart, zslope
end


function zscale(image, nsamples=1000, contrast=0.25)

    #=
    Implement IRAF zscale algorithm
    Parameters
    ----------
    image : arr
        2-d numpy array
    nsamples : int (Default: 1000)
        Number of points in array to sample for determining scaling factors
    contrast : float (Default: 0.25)
        Scaling factor for determining min and max. Larger values increase the
        difference between min and max values used for display.

    Returns
    -------
    (z1, z2)
    =#

    # Sample the image
    nsamples = minimum([nsamples, length(image)])
    samples = zsc_sample(image, nsamples)
    npix = length(samples)
    sort!(samples)
    
    zmin = samples[1]
    zmax = samples[end]

    # For a one-indexed array
    if npix % 2 == 1
        center_pixel = Int128(round((npix + 1) / 2))
        median = samples[center_pixel]
    else
        Int128(round(npix / 2))
        median = 0.5 * (samples[center_pixel] + samples[center_pixel + 1])
    end

    # Fit a line to the sorted array of samples
    minpix = maximum([MIN_NPIXELS, Int128(npix * MAX_REJECT)])
    ngrow = maximum([1, Int128(npix * 0.01)])
    ngoodpix, zstart, zslope = zsc_fit_line(samples, npix, KREJ, ngrow, MAX_ITERATIONS)

    if ngoodpix < minpix
        z1 = zmin
        z2 = zmax
    else
        if contrast > 0 
            zslope = zslope / contrast
        end
        if npix % 2 == 1
            z1 = maximum([zmin, median - (center_pixel - 1) * zslope])
            z2 = minimum([zmax, median + (npix - center_pixel) * zslope])
        else
            z1 = maximum([zmin, median - (center_pixel - 0.5) * zslope])
            z2 = minimum([zmax, median + (npix - center_pixel - 0.5) * zslope])
        end
    end

    return z1, z2
end
