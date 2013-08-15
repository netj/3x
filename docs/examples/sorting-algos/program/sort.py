# sorting algorithms

import random

def swap(A, i, j):
    if i != j:
        A[i], A[j] = A[j], A[i]


# See: http://en.wikipedia.org/wiki/Bubble_sort#Pseudocode_implementation
def bubbleSort(A):
    numComp = numAccess = 0

    n = len(A)
    swapped = True
    while swapped and n > 1:
        swapped = False
        for i in range(1, n):
            numAccess += 2
            numComp += 1
            if A[i-1] > A[i]:
                numAccess += 2 # two writes by swap (A[i-1], A[i] already read)
                swap(A, i-1, i)
                swapped = True
        n -= 1

    return {
            "#comparisons" : numComp,
            "#accesses"    : numAccess,
            }


# See: http://en.wikipedia.org/wiki/Selection_sort
def selectionSort(A):
    numComp = numAccess = 0

    n = len(A)
    for i in range(0, n-1):
        k = i
        numAccess += 1
        a = A[k]
        for j in range(i+1, n):
            numAccess += 1
            b = A[j]
            numComp += 1
            if b < a:
                k = j
                a = b
        if i != k:
            numAccess += 3 # two writes + read A[i] by swap
        swap(A, i, k)

    return {
            "#comparisons" : numComp,
            "#accesses"    : numAccess,
            }


# See: http://en.wikipedia.org/wiki/Insertion_sort#Algorithm
def insertionSort(A):
    numComp = numAccess = 0

    n = len(A)
    for i in range(1, n):
        numAccess += 1
        a = A[i]
        j = i
        while j > 0:
            numAccess += 1
            b = A[j-1]
            numComp += 1
            if a < b:
                numAccess += 1
                A[j] = b
                j -= 1
            else:
                break
        numAccess += 1
        A[j] = a

    return {
            "#comparisons" : numComp,
            "#accesses"    : numAccess,
            }


# See: http://en.wikipedia.org/wiki/Quicksort#In-place_version
def quickSort(A):
    global numComp, numAccess
    numComp = numAccess = 0

    def partition(A, left, right, pivotIndex):
        global numComp, numAccess
        numAccess += 4 # two writes + two reads by swap
        pivotValue = A[pivotIndex]
        swap(A, pivotIndex, right)
        storeIndex = left
        for i in range(left, right):
            numAccess += 1
            numComp += 1
            if A[i] < pivotValue:
                if i != storeIndex:
                    numAccess += 3 # two writes + one read by swap (A[i] already read)
                swap(A, i, storeIndex) # TODO maybe we don't need swap here, just shift
                storeIndex += 1
        if storeIndex != right:
            numAccess += 4 # two writes + two reads by swap
        swap(A, storeIndex, right)
        return storeIndex

    def qsort(A, left, right):
        if left < right:
            pivotIndex = random.randint(left, right)
            pivotNewIndex = partition(A, left, right, pivotIndex)
            qsort(A, left, pivotNewIndex-1)
            qsort(A, pivotNewIndex+1, right)

    qsort(A, 0, len(A)-1)

    return {
            "#comparisons" : numComp,
            "#accesses"    : numAccess,
            }


# See: http://en.wikipedia.org/wiki/Merge_sort#Bottom-up_implementation
def mergeSort(C):
    global numComp, numAccess
    numComp = numAccess = 0

    def merge(A, left, right, end, B):
        global numComp, numAccess
        i = left
        j = right
        for k in range(left, end):
            numAccess += 2 # always one read (A[i] or A[j]) and a write (to B[k])
            use_x = False
            if i < right:
                x = A[i]
                if j >= end:
                    use_x = True
                else:
                    numAccess += 1 # A[j] also read
                    y = A[j]
                    numComp += 1
                    if x <= y:
                        use_x = True
            else:
                y = A[j]
            if use_x:
                B[k] = x
                i += 1
            else:
                B[k] = y
                j += 1

    A = C
    N = len(A)
    B = N * [None]

    width = 1
    while width < N:
        for i in range(0, N, 2*width):
            merge(A, i, min(i+width, N), min(i+2*width, N), B)
        A, B = B, A
        width *= 2

    C[:] = A

    return {
            "#comparisons" : numComp,
            "#accesses"    : numAccess,
            }

