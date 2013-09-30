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
easily obtain robust, repeatable experimental results with minimal effort.
Therefore more of our time and energy can be devoted to exploring the parameter
space as well as writing the program correctly, which leads our experiments to
yield more interesting results and less errors.


### 1. Write the Program
First of all, we need to write a program that implements the sorting algorithms
we want to test.  Some people may prefer using a serious programming language,
such as C, C++, or Java to write an efficient implementation.  Others may use
simpler scripting languages, such as Python, Ruby or Perl for a quick
evaluation.  But in the end, there will always be an executable file, or a
command and a list of arguments to start our program regardless of the
programming language of choice.  This is the only thing 3X needs to know about
the program for our experiment, and we will see where this information should
be placed after we create an *experiment repository* in the following step.

To keep this tutorial simple, let's assume we already wrote Python code for
experimenting with sorting algorithms as following two files:

* [`sort.py`][]
    containing each sorting algorithm as a separate Python function.

* [`measure.py`][]
    containing code that measures how long a chosen sorting algorithm takes to
    finish for a generated input.

[`sort.py`]:    examples/sorting-algos/program/sort.py
[`measure.py`]: examples/sorting-algos/program/measure.py

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


### 2. Create and Setup an Experiment Repository

In order to keep everything related to our experiment well organized, we need
to tell 3X to create a new *experiment repository* for us.  Every detail from
the definition of input/output and program to the individual records of past
executions and plans for future runs will be stored and managed inside this
repository.  It is a typical directory (or folder) on the filesystem with a
special internal structure.

3X provides two different ways to setup a new experiment repository: a quick
one-liner setup, or a slightly more lengthy step-by-step way.  The quick setup
will be useful for creating entirely new experiments from scratch, while the
step-by-step setup can be useful for adjusting your existing experiment
definitions.  You can either follow the first "Quick Setup" section and skip
the rest, or follow the individual steps introduced in the sections that
follows "Quick Setup".  In either ways, let's say we want our repository to be
called `sorting-algos`.  

#### Quick Setup

The single command shown below will create and setup a new repository for our
experiment on sorting algorithms.  It is simply an abbreviation for the
multiple steps necessary to initialize the experiment repository and define its
input and output.

    # create and setup a new experiment repository
    3x setup sorting-algos \
        --program \
            'python measure.py $algo $inputSize $inputType' \
        --inputs \
            inputSize=10,11,12,13,14,15,16,17,18 \
            inputType=random,ordered,reversed \
            algo=bubbleSort,selectionSort,insertionSort,quickSort,mergeSort \
        --outputs \
            --extract 'sorting time \(s\): {{sortingTime(s) =~ .+}}' \
            --extract 'number of compares: {{numCompare =~ .+}}' \
            --extract 'number of accesses: {{numAccess =~ .+}}' \
            --extract 'ratio sorted: {{ratioSorted =~ .+}}' \
            --extract 'input generation time \(s\): {{inputTime(s) =~ .+}}' \
            --extract 'validation time \(s\): {{validationTime(s) =~ .+}}' \
        #

Note that since this quick setup command creates only the skeleton part of our
experiment repository, we still need to place additional files at the right
place, namely, the `.py` files of our program.  Refer to the [instructions for
registering the program (§2.3)](#registertheprogram) to prepare the `program/`
directory.  You can safely ignore the rest of the steps, since they were
already taken care by the `3x setup` command above.  We'll all set to start
running our experiment.


#### 2.1. Create an Experiment Repository

The following command creates an empty repository:

    3x init sorting-algos

We can now move into the repository to further define our experiment.

    cd sorting-algos


#### 2.2. Define Inputs & Outputs
Next, we shall tell 3X what are the input parameters to our experimental
program, and the output values of interest.

##### Define Input Parameters
Suppose we want to vary the input size, the initial order of input for
different sorting algorithms.  We can tell 3X that we have three input
parameters for our experiment in the following steps.

1. **`algo`** for choosing the sorting algorithm to test

    The particular sorting algorithms we are interested in are the following
    five, which are already implemented in [`sort.py`][].  We will use the name
    of the algorithms as the value for this input parameter.

    * `bubbleSort`      for [Bubble Sort](http://en.wikipedia.org/wiki/Bubble_sort#Pseudocode_implementation)
    * `selectionSort`   for [Selection Sort](http://en.wikipedia.org/wiki/Selection_sort)
    * `insertionSort`   for [Insertion Sort](http://en.wikipedia.org/wiki/Insertion_sort#Algorithm)
    * `quickSort`       for [Quick Sort (in-place version)](http://en.wikipedia.org/wiki/Quicksort#In-place_version)
    * `mergeSort`       for [Merge Sort (bottom-up implementation)](http://en.wikipedia.org/wiki/Merge_sort#Bottom-up_implementation)

    The following command tells 3X to add this parameter to the experiment definition:

        3x define input  algo  bubbleSort selectionSort insertionSort quickSort mergeSort 


2. **`inputSize`** for choosing the size of the array to sort

    We want to test sorting algorithms on arrays of numbers with different
    sizes.  We will start with arrays of 1,024 (2<sup><small>10</small></sup>)
    unique numbers, and double the size of the arrays up to size 262,144
    (2<sup><small>18</small></sup>).  Let's omit the base and use the powers of
    two as the value for this input parameter:

    * `10` for 2<sup><small>10</small></sup>,
    * `11` for 2<sup><small>11</small></sup>,
    * ...,
    * `18` for 2<sup><small>18</small></sup>.

    We should run the following command to add this parameter:

        3x define input  inputSize  10 11 12 13 14 15 16 17 18


3. **`inputType`** for choosing the type of the arrays to sort

    We also want to see how each sorting algorithm behaves differently for
    different types of arrays as well as their sizes.  We will use the
    following three values of this input parameter to indicate which type of
    input we want to use:

    * `ordered` that is already sorted,
    * `reversed` that is sorted but in the reversed direction,
    * `random` that is shuffled randomly.

    The following command will add this last parameter:

        3x define input  inputType  ordered reversed random

    
##### Define Output Variables

Next, suppose we want to measure the wall clock time as well as the number of
compares and array accesses to finish each sorting algorithm.  We can tell
3X to look for lines that match specific patterns in the output of our program
to extract the values of interest.  These patterns can be specified in [Perl
regular expressions](http://perldoc.perl.org/perlre.html#Regular-Expressions)
syntax.  The following steps will show how exactly we can tell 3X to extract
the values of interest in the case of this experiment with sorting algorithms.

1. **`sortingTime`**

    The wall clock time it takes for sorting the input array is what we are
    mostly interested in this experiment.  We measure this time in our program
    in seconds and print that out in a line that begins with `sorting time (s):
    `.  Therefore 3X can easily extract the value that follows if we define the
    output variable as shown in the following command:
    
        3x define output  'inputTime(s)'  'sorting time \(s\): '  '.+'  ''
    
    Here, there are four arguments to the `3x define output` command:

    1. name of the output variable: `inputTime(s)`
    2. regular expression for the text that comes before the value: `sorting time \(s\): `
    3. regular expression the value matches: `.+` (any non-empty string)
    4. regular expression for the text that comes after the value: (empty string)
    
    Note that we can append the *unit* of the output variable to its name
    (first argument), which is `(s)` or seconds in this case.  We can use any
    text for the unit as long as it's surrounded by parentheses.

2. **`numCompare`**

    Similarly, we can teach 3X to extract the number of compares for the value
    of an output variable using the following command:
    
        3x define output  'numCompare'  'number of compares: '  '.+'  ''

3. **`numAccess`**

    As well as the number of accesses to the input array of numbers with:
    
        3x define output  'numAccess'  'number of accesses: '  '.+'  ''

4. **`ratioSorted`**

    To ensure correctness, note that we compute the ratio of the numbers in the
    array that are correctly ordered to the array size, after finishing the
    sorting algorithm.  This is a simple measure to easily check whether the
    sorting algorithm was implemented correctly.  When this value comes out
    less than 1.0, it means the the algorithm is incorrect.  The following
    command adds this output variable to the experiment definition.
    
        3x define output  'ratioSorted'  'ratio sorted: '  '.+'  ''

5. **`inputTime`**

    We also record the wall clock time that took for generating the input array
    to sort.
    
        3x define output  'inputTime(s)'  'input generation time \(s\): '  '.+'  ''

6. **`validationTime`**

    And the wall clock time that took for checking whether the output array is
    correctly sorted.
    
        3x define output  'validationTime(s)'  'validation time \(s\): '  '.+'  ''


#### 2.3. Register the Program

The only thing 3X needs to know about our program in order to run experiments
on behalf of us is the exact command we type into our terminal to start them
ourselves.  3X assumes this information is kept as an executable file named
**`run`** under the `program/` directory of the experiment repository.  For
each execution of `run`, 3X sets up the environment correctly, so that the
value chosen for each input variable we defined earlier can be accessed via the
environment variable with the same name.  3X will also make sure any additional
files that are placed next to the `run` executable will also be available in
the current working directory while execution.


First, let's move into the `program/` directory of our repository:

    cd program


As we have two Python files necessary for implementing and measuring the
sorting algorithms, we will put both of these files under `program/`.  If you
don't have these files readily available, let's download them directly from
GitHub with the following commands:

    # copy our example Python program into the repository
    exampleURL="https://raw.github.com/netj/3x/master/docs/examples/sorting-algos"
    curl -LO $exampleURL/program/{measure.py,sort.py}

(You can probably use `wget` instead of `curl -LO` if your system doesn't have
`curl` installed.)

Next, we need to create a `run` script that starts our Python program as
follows:

    cat >run  <<EOF
    #!/bin/sh
    python measure.py $algo $inputSize $inputType
    EOF
    chmod +x run

Now, we're all set to start running our experiment.



### 3. Start GUI

...

### 4. Plan Runs

...

### 5. Tabulate Results

...

### 6. Chart Results

...


* * *

## Example 2: Simulating Network Formations
...


* * *

## Example 3: Finding a Good Word-Cloud
...
