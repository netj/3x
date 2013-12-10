#!/usr/bin/env python

import os,sys
import random
import time

### how to generate input list of given size

def generatePartiallyReversedArray(N, percentOrdered):
    if percentOrdered >= 50:
        A = []
        begin, end = 0, N-1
        toReverse = N - round(N * float(percentOrdered) / 100)
        while toReverse > 0: # and begin < end: # (latter condition always true for percentOrdered >= 50)
            if random.randint(0,1) == 0:
                A.append(begin)
                begin += 1
            else:
                A.append(end)
                end -= 1
                toReverse -= 1
        return A + range(begin, end + 1)
    else:
        A = generatePartiallyReversedArray(N, 100 - percentOrdered)
        A.reverse()
        return A

def generateOrderedInput (N):
    return range(0,N)

def generateReversedInput(N):
    return range(N-1,-1, -1)

def generateRandomInput  (N):
    A = range(0,N)
    random.shuffle(A)
    return A

inputGenerators = {
    "ordered"  : generateOrderedInput,
    "reversed" : generateReversedInput,
    "random"   : generateRandomInput,
}


### what data sizes
dataSizes = {
    "small"  : 2000,
    "medium" : 4000,
    "large"  : 8000,
}


### how to sort a given list

import sort

sortingAlgorithms = {
    "bubbleSort"    : sort.bubbleSort,
    "selectionSort" : sort.selectionSort,
    "insertionSort" : sort.insertionSort,
    "quickSort"     : sort.quickSort,
    "mergeSort"     : sort.mergeSort,
}


### how to verify whether result is correctly sorted

def computeMisordered(A):
    N = len(A)
    numMisordered = 0
    i = 0
    while i+1 < N:
        if A[i] > A[i+1]:
            numMisordered += 1
        i += 1
    return float(N - numMisordered) / float(N)


### how to decide input parameter values
try:
    # we collect input parameters from the environment variables
    if len(sys.argv) <= 3:
        raise Exception("Missing argument")
    algo  = sys.argv[1]
    size  = sys.argv[2]
    order = sys.argv[3]

    N = dataSizes[size] if size in dataSizes else int(size)

    generateList = inputGenerators[order] if order in inputGenerators else lambda N: generatePartiallyReversedArray(N, float(order))
    sortList     = sortingAlgorithms[algo]
except Exception as e:
    print >> sys.stderr, e
    print "Usage: ./measure.py  SORTING_ALGO  DATA_SIZE  DATA_ORDER"
    print """
    SORTING_ALGO is one of the following sorting algorithms:
        bubbleSort
        selectionSort
        insertionSort
        quickSort
        mergeSort

    DATA_SIZE is small, medium, large, or the number of items, e.g.,
        small is %(small)d items, medium is %(medium)d, and large is %(large)d.
        1000000 specifies a million items to be sorted.

    DATA_ORDER is one of random, sorted, reversed, or the percentage sorted, e.g.,
        90 specifies 90%% of the items in the input list to be sorted if we
            removed the 10%% that are inserted into random points in reversed order.
        random is equivalent to 50, i.e., a completely randomly shuffled list.
        sorted is equivalent to 100, i.e., a completely sorted list.
        reversed is equivalent to 0, i.e., a completely reversed list.
    """ % dataSizes
    sys.exit(1)


### and the actual measurement
timings = {}


# first, generate input
start = time.clock()
inputList = generateList(N)
score = computeMisordered(inputList)
end = time.clock()
timings["input generation"] = end - start
print "input sorted ratio:", score

# then, sort with the given algorithm
theList = list(inputList)
start = time.clock()
sortStats = sortList(theList)
end = time.clock()
timings["sorting"] = end - start

# check and report how much the algorithm sorted correctly
start = time.clock()
score = computeMisordered(theList)
end = time.clock()
timings["verification"] = end - start
print "output sorted ratio:", score


# report timings
for task,t in timings.iteritems():
    print "%s time (s): %f" % (task, t)

# and other statistics
for name,value in sortStats.iteritems():
    print "%s: %s" % (name, str(value))
