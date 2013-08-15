# <i class="icon-beaker"></i> 3X Tutorial: Step-through Examples
<style>@import url(http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css);</style>

In this document, we explain how you can setup and conduct computational
experiments using a few examples.  This step-by-step guide will introduce
important features of 3X with detailed instructions.


## Example 1: Studying Sorting Algorithms

Anyone who received computer science education or studied basic algorithms
would be familiar with several different classes of algorithms for sorting an
array of data values.  In the algorithms textbook, we learn how to analyze time
and space complexities of such algorithms in terms of their asymptotic
behavior.  Theoretical analyses of worst or best cases can be covered clearly
in text, but average cases require empirical studies experimenting with actual
implementations.

Suppose we want to see such an empirical result ourselves of how different
sorting algorithms, namely, *bubble sort*, *selection sort*, *insertion sort*,
*quick sort*, and *merge sort* behave on several sizes and types of inputs,
e.g., when the input is already ordered, reversed, or randomly shuffled.
Implementing those algorithms correctly is obviously important, but what's
equally important to obtain a credible result is running different combinations
of inputs and recording every detail in a systematic manner.


### 1. Inputs & Outputs
...

### 2. Setup

    3x setup sorting-algos \
        --inputs \
            inputSize=10,11,12,13,14,15,16,17,18 \
            inputType=random,ordered,reversed \
            algo=bubbleSort,selectionSort,insertionSort,quickSort,mergeSort \
        --outputs \
            --extract 'sorting time \(s\): {{sortingTime(s) =~ .+}}' \
            --extract 'input generation time \(s\): {{inputTime(s) =~ .+}}' \
            --extract 'ratio sorted: {{ratioSorted =~ .+}}' \
            --extract '#comparisons: {{numCompare =~ .+}}' \
            --extract '#accesses: {{numAccess =~ .+}}' \
        #


* * *

## Example 2: Simulating Network Formations
...


* * *

## Example 3: Finding a Good Word-Cloud
...
