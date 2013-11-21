# <i class="icon-beaker"></i> 3X Features Overview

In this document, we give a tour of the features of <span class="sans-serif">3X</span> as terms and concepts are introduced in the order of a typical workflow.
The primary three modes of 3X, each of which will be described in turn, are for organizing experiments, running them, and exploring and analyzing their results.
Refer to [other documents](../../#further-information) for instructions on how to install the software and how to use individual features of <span class="sans-serif">3X</span>.

## Organize Experiments with 3X

Definition of any computational experiment can be logically decomposed into three parts: program, input variables, and output variables.
<span class="sans-serif">3X</span> provides a flexible structure for organizing the files that define your experiment according to these logical parts as well as the files that are produced by executing your experiment.

### Experiment Repository
An *experiment repository* is where <span class="sans-serif">3X</span> keeps all data related to an experiment.
It is an ordinary filesystem directory dedicated to your experiment, where you can organize your own files for the experiment under <span class="sans-serif">3X</span>'s standard structure.
It keeps records of all data produced by executing your program, and can hold code of your program as well as input data that will be fed to it.
New experiment repositories can be created easily with a single command (`3x setup`).

### Program
*Program* is what you want to run (or execute) to do the computation for your experiment.
Most programs will output computed data as files or standard output/error based on the input you give, and can be thought as a function.
But <span class="sans-serif">3X</span> works fine with programs that have randomness in them producing different results on each execution even with the same input, or programs that mutate state of external systems, e.g., databases.
When your experiment is about comparing different algorithms or implementations for the same set of inputs, although you may have multiple codes to execute, your program to 3X is the code that combines all of them by executing the actual one based on a designated input switch.
As long as there is a way to invoke your program from the command-line, <span class="sans-serif">3X</span> is agnostic to what programming language or programming system you are using.
For example, you can use <span class="sans-serif">3X</span> to play with small Python scripts on your laptop, to run MATLAB/Octave code on your compute cluster, or to launch complex jobs on your Hadoop cluster.

### Input Variables
*Input variables* are what you want to vary between executions of your program.
You can specify a finite set of discrete, symbolic values for each input variable, e.g., `insertionSort`, `quickSort`, and `mergeSort`, etc. for input variable `algo` that determines which sorting algorithm is used.
<span class="sans-serif">3X</span> supplies values for the input variables to your experiment program in the form of environment variables.
A filesystem directory is provided for each input variable and each value of it to let you organize relevant input files in a manifest way.

### Output Variables
*Output variables* are what you want to extract from the result of each execution of your program.
<span class="sans-serif">3X</span> lets you specify a set of regular expressions to extract for an output variable a piece of text from the standard output/error of your experiment program.
If an output of your experiment is an image file, you can specify its filename instead.
In fact, this phase of extracting data for output variables is entirely extensible, not limiting you to these built-in options.
You can use another set of your own programs, called *extractors*, to perform various computations, which can be much more complex than simply searching for pieces of text or files, on the data produced by your original experiment program.



## Run Experiments with 3X

Once you have a computational experiment properly set up with <span class="sans-serif">3X</span>, you can use its suite of tools to plan, control, and manage the execution of your experiment program.
You can easily generate a combination of value bindings for your input variables from a manually selected subset of values, and order them in a way you want to execute.
<span class="sans-serif">3X</span> can execute your program on your local machine or a remote host via SSH one at a time, or on a cluster of machines in parallel.

### Run
A *run* is a unit of single execution of your experiment program given the bindings of a value for each of the input variables.
State of a run is one among `PLANNED`, `RUNNING`, `ABORTED`, `FAILED`, or `DONE`, depending on whether it is to be executed, is executing, or was executed.
Every run gets a unique *run identifier* (`run#`) assigned once it starts execution, i.e., all runs except the `PLANNED` ones have unique run identifiers.
Each run has its *run directory*, whose path under the repository root is the run's identifier, which records all data that goes into and comes out of the program for that run.
As identical copies of files are very likely to exist across many runs, <span class="sans-serif">3X</span> automatically detects them and de-duplicates into a single copy to use storage space efficiently.

### Queue
*Queue* is a list of runs where <span class="sans-serif">3X</span> keeps track of its execution order of the `PLANNED` runs, the status of executing runs, and the history of finished runs.
It is the point of control of execution, where you can *start a queue* to execute runs that have been or will be added to the queue, and *stop the queue* to abort any executing runs in it.
Multiple queues can be used to organize large number of runs into smaller groups.

### Target
*Target* defines where and under what environment your runs will execute.
Each queue has an associated target where its `PLANNED` runs will be sent for execution.
For example, you can tie one queue to a target for your local machine and another queue to a target for a remote machine, then execute different groups of runs on these two targets.



## Explore and Analyze Results with 3X

As soon as your runs finish execution, their results can be instantly visualized using the <span class="sans-serif">3X</span> GUI (graphical user interface).
Visualizations provided by <span class="sans-serif">3X</span> are more powerful than static pictures of your results data, because they allow interactions for tracing provenance of any visible data point and drilling down to another form of visualization.

### Table
<span class="sans-serif">3X</span> table displays the input values and output data of your runs as rows and columns.
You have control of which columns are visible in the table, how they are ordered, by which input variables the rows in the table are grouped, what aggregate statistic of grouped rows are shown for each column, and what conditions each visible row should satisfy.
Multiple aggregate statistics for an output variable can be shown at the same time, e.g., mean, standard deviation, median, min, max, mode, and count, where the variable's data type decides which statistics are available.
Any aggregate cell in the table can be inspected to trace records of individual runs that contribute to it.
When you want to augment some of the rows with data from new runs, the additional runs can be planned directly from the table.

### Chart
<span class="sans-serif">3X</span> chart displays the data shown in the table as a two-dimensional figure.
Multiple input and output variables of interest can be chosen to automatically create a chart based on the type and range of the data.
When you specify more than two variables (for X- and Y-axes), <span class="sans-serif">3X</span> figures out which of the chosen variables map to a second Y-axis or distinguish the series in the chart.
Currently, only line charts and scatter plots with simple options can be drawn.
Any visual element in these automatically generated charts are interactive, inviting you to inspect what runs have made up the data point and drill down to a more specific visualization.


----

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
