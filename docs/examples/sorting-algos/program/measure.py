#!/usr/bin/env python

import os,sys
import random
import time

### how to generate input list of given size

def generateOrderedInput (N):
    return range(0,N)

def generateReversedInput(N):
    return range(N,0,-1)

def generateRandomInput  (N):
    A = range(0,N)
    random.shuffle(A)
    return A

inputGenerators = {
    "ordered"  : generateOrderedInput,
    "reversed" : generateReversedInput,
    "random"   : generateRandomInput,
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

def verifyOutput(A):
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
    algo      = sys.argv[1]
    inputSize = sys.argv[2]
    inputType = sys.argv[3]

    N = 2 ** int(inputSize)

    generateList = inputGenerators[inputType]
    sortList     = sortingAlgorithms[algo]
except Exception as e:
    print >> sys.stderr, e
    print "Usage: ./measure.py  SORTING_ALGO  INPUT_SIZE  INPUT_TYPE"
    print """
    SORTING_ALGO is one of the following sorting algorithms:
        bubbleSort
        selectionSort
        insertionSort
        quickSort
        mergeSort

    INPUT_SIZE is the two's power, e.g.,
        inputSize=10 specifies an input list with 1024 items.

    INPUT_TYPE is one of random, ordered, or reversed, e.g.,
        inputType=random
    """
    sys.exit(1)


### and the actual measurement
timings = {}


# first, generate input
start = time.clock()
inputList = generateList(N)
end = time.clock()
timings["input generation"] = end - start

# then, sort with the given algorithm
theList = list(inputList)
start = time.clock()
sortStats = sortList(theList)
end = time.clock()
timings["sorting"] = end - start

# check and report how much the algorithm sorted correctly
start = time.clock()
score = verifyOutput(theList)
end = time.clock()
timings["verification"] = end - start
print "ratio sorted:", score


# report timings
for task,t in timings.iteritems():
    print "%s time (s): %f" % (task, t)

# and other statistics
for name,value in sortStats.iteritems():
    print "%s: %s" % (name, str(value))
