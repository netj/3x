# <i class="icon-beaker"></i> 3X Tutorial: Step-through Examples
<style>@import url(http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css);</style>

In this document, we explain how you can setup and conduct computational
experiments using a few examples.  This step-by-step guide will introduce
important features of 3X with detailed instructions.


## Example 1: Studying Sorting Algorithms

Anyone who received computer science education or studied basic algorithms
would be familiar with different algorithms for sorting an array of data
values.  In the algorithms textbook, we learn how to analyze time and space
complexities of such algorithms in terms of their asymptotic behavior.
Theoretical analyses of worst or best cases can be covered clearly in text, but
average cases require empirical studies experimenting with actual
implementations.

Suppose we want to see such an empirical result ourselves of how different
sorting algorithms, namely, *bubble sort*, *selection sort*, *insertion sort*,
*quick sort*, and *merge sort* behave on several sizes and types of inputs,
e.g., when the input is already ordered, reversed, or randomly shuffled.
Implementing those algorithms correctly is obviously important, but what's
equally important to obtain a credible result is running different combinations
of inputs and recording every detail in a systematic manner.  Using 3X, we can
easily obtain robust, repeatable experimental results without the hard work.
We can therefore focus most of our time and effort on writing correct sorting
algorithms and exploring the input parameter space.

### 1. Write the Program
First of all, we need to write a program that implements the sorting algorithms
we want to test.  Some people may prefer using a serious programming language,
such as C, C++, or Java to write an efficient implementation.  Others may use
simpler scripting languages, such as Python, Ruby or Perl for a quick
evaluation.  But in the end, there will be an executable file, or a command and
a list of arguments to start our program regardless of the programming language
of choice.  This is the only thing 3X needs to know about our experimental
program, and where you should put this information will be described after we
create an *experiment repository* in the following step.

To keep this tutorial simple, let's assume we already wrote Python code for
experimenting with sorting algorithms as following two files:

* [`sort.py`](examples/sorting-algos/program/sort.py)
    containing each sorting algorithm as a separate Python function.

* [`measure.py`](examples/sorting-algos/program/measure.py)
    containing code that measures how long a chosen sorting algorithm takes to
    finish for a generated input.

To obtain a single measurement with this program, we would a run command such
as:

    python measure.py quickSort 10 random

which outputs, for instance:

    ratio sorted: 1.0
    sorting time (s): 0.009179
    verification time (s): 0.000225
    input generation time (s): 0.000580
    number of compares: 11440
    number of accesses: 30735


### 2. Create an Experiment Repository

In order to keep everything related to our experiment well organized, we need
to tell 3X to create a new *experiment repository* for us.  Every detail from
the definition of input/output and program to the individual records of past
executions and plans for future runs will be stored and managed inside this
repository.  It is a typical directory (or folder) on the filesystem with a
special internal structure.

Let's say we want our repository to be called `sorting-algos`.  The following
command creates an empty repository:

    3x init sorting-algos


### 3. Define Inputs & Outputs
Next, we shall tell 3X what are the input parameters to our experimental
program, and the output values of interest.  Since we want to vary the input
size, the initial order of input for different sorting algorithms, following
three are the inputs:

1. inputSize
    


2. inputType

    

3. algo

    

### 4. Register the Program

The only thing 3X needs to know about our program in order to run experiments
on behalf of us is the exact command we type into our terminal to start them
ourselves.  3X assumes this information is kept as an executable file named
**`run`** under the `program/` directory of the experiment repository.  For
each execution of `run`, 3X sets up the environment correctly, so that the
value chosen for each input variable we defined earlier can be accessed via the
environment variable with the same name.  3X will also make sure any additional
files that are placed next to the `run` executable will also be available in
the current working directory while execution.

As we have two Python files necessary for implementing and measuring the
sorting algorithms, we will put both of these files under `program/` and create
a `run` script as follows:

    python measure.py $algo $inputSize $inputType



### 5. Setup in a Single Step

    3x setup sorting-algos \
        --inputs \
            inputSize=10,11,12,13,14,15,16,17,18 \
            inputType=random,ordered,reversed \
            algo=bubbleSort,selectionSort,insertionSort,quickSort,mergeSort \
        --outputs \
            --extract 'sorting time \(s\): {{sortingTime(s) =~ .+}}' \
            --extract 'input generation time \(s\): {{inputTime(s) =~ .+}}' \
            --extract 'ratio sorted: {{ratioSorted =~ .+}}' \
            --extract 'number of compares: {{numCompare =~ .+}}' \
            --extract 'number of accesses: {{numAccess =~ .+}}' \
        #


* * *

## Example 2: Simulating Network Formations
...


* * *

## Example 3: Finding a Good Word-Cloud
...
