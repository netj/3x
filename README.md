# <i class="icon-beaker"></i> 3X
## A tool for eXecutable eXploratory eXperiments

3X is a software tool for conducting computational experiments in a systematic way.
Organizing the data that goes into and comes out of experiments, as well as maintaining the infrastructure for running them, is generally regarded as a tedious and mundane task.
Often times we end up in a suboptimal environment improvised and hard-coded for each experiment.
The problem is exacerbated when the experiments must be performed iteratively for exploring a large parameter space.
It is obvious that easing this burden will enable us to more quickly make interesting discoveries from the data our experiments produce.
So-called "data scientists" are emerging everywhere these days to ask questions in the form of computational experiments, and to discover new facts from the "big data" their institutions have accumulated.
In fact, these computational and data-driven approaches have long been a standard method for doing science in many domains, and we see ever growing number of fields depending on computational experiments.
3X provides a standard yet configurable structure for us to execute a wide variety of experiments.
It organizes code/inputs/outputs for the experiment, records results, and lets us visualize the data and drive execution interactively.
Using 3X we can understand much better of what's being explored by our experiments with significantly less effort and error.

In the following sections, we define terms and concepts used by 3X, and describe what the workflow will be like to use 3X to run, explore, and analyze your own experiments.
Refer to [other documents](#further-reading) for instructions to obtain the software, or more details on individual features of 3X.


### Organize Experiments with 3X

Any computational experiment can be logically decomposed into three parts: program, input and output variables.
3X provides a flexible structure for organizing the files of your experiment according to these logical parts.
As an example, let's consider an "empirical study of sorting algorithms' time complexity" in the rest of this section.

#### Experiment Repository
An *experiment repository* is where 3X keeps all data related to an experiment.
It is an ordinary filesystem directory dedicated to your experiment, where you can organize your own files for the experiment under 3X's standard structure.
It keeps record of all data produced by executing your program, and can hold code of your program as well as input data that will be fed to it.
New experiment repositories can be created easily with a single command (`3x setup`).

#### Program
*Program* is what you want to run (or execute) to do the computation for your experiment.
In our example, implementations of the different sorting algorithms, such as bubble sort, quick sort, merge sort, etc., as well as the code for measuring execution time and number of comparisons constitute the experiment program.
Most programs will output computed data as files or standard output/error based on the input you give, and can be thought as a function.
But 3X works fine with programs that have randomness in them producing different results on each execution even with the same input, or programs that mutate state of external systems, e.g., databases.
As long as there is a way to invoke your program from the command-line, 3X is agnostic to what programming language or programming system you are using.
For example, you can use 3X to play with small Python scripts on your laptop, to run MATLAB/Octave code on your compute cluster, or to launch complex jobs on your Hadoop cluster.

#### Input Variables
*Input variables* are what you want to vary between executions of your program.
In our example, the size and characteristics of the input to the sorting algorithm, as well as which sorting algorithm to use are the input variables.
You can specify a finite set of discrete, symbolic values for each input variable, e.g., `insertionSort`, `quickSort`, and `mergeSort`, etc. for input variable `algo` that determines which sorting algorithm is used.
3X supplies values for the input variables to your experiment program in the form of environment variables.
A filesystem directory is provided for each input variable and each value of it to let you organize relevant input files in a manifest way.

#### Output Variables
*Output variables* are what you want to extract from the result of each execution of your program.
In our example, the time and numbers measured are the output variables.
3X lets you specify a set of regular expressions to extract for an output variable a piece of text from the standard output/error of your experiment program.
If an output of your experiment is an image file, you can specify its filename instead.
In fact, this phase of extracting data for output variables is entirely extensible, not limiting you to these built-in options.
You can use another set of your own programs, called *extractors*, to perform various computations, which can be much more complex than simply searching for pieces of text or files, on the data produced by your original experiment program.



### Run Experiments with 3X

Once you have a computational experiment properly set up with 3X, you can use its powerful tools to plan, control, and manage the execution of your experiment program.
You can easily generate a combination of value bindings for your input variables from a manually selected subset of values, and order them in a way you want to execute.
3X can execute your program on your local machine or a remote host via SSH one at a time, or on a cluster of machines in parallel.

#### Run
A *run* is a unit of single execution of your experiment program given the bindings of a value for each of the input variables.
State of a run is one among `PLANNED`, `RUNNING`, `ABORTED`, `FAILED`, or `DONE`, depending on whether it is to be executed, is executing, or was executed.
Every run gets a unique *run identifier* (`run#`) assigned once it starts execution, i.e., all runs except the `PLANNED` ones have unique run identifiers.
Each run has its *run directory*, whose path under the repository root is the run's identifier, which records all data that goes into and comes out of the program for that run.
As identical copies of files are very likely to exist across many runs, 3X automatically detects them and de-duplicates into a single copy to use storage space efficiently.

#### Queue
*Queue* is a list of runs where 3X keeps track of its execution order of the `PLANNED` runs, the status of executing runs, and the history of finished runs.
It is the point of control of execution, where you can *start a queue* to execute runs that have been or will be added to the queue, and *stop the queue* to abort any executing runs in it.
Multiple queues can be used to organize large number of runs into smaller groups.

#### Target
*Target* defines where and under what environment your runs will execute.
Each queue has an associated target where its `PLANNED` runs will be sent for execution.
For example, you can tie one queue to a target for your local machine and another queue to a target for a remote machine, then execute different groups of runs on these two targets.



### Explore and Analyze Results with 3X

As soon as your runs finish execution, their results can be instantly visualized using the 3X GUI (graphical user interface).
Visualizations provided by 3X are profoundly more powerful than static pictures of your results data, because they allow interactions for tracing provenance of any visible data point and drilling down to another form of visualization.

#### Table
3X table displays the input values and output data of your runs as rows and columns.
You have complete control of which columns are visible in the table, how they are ordered, by which input variables the rows in the table are grouped, what aggregate statistic of grouped rows are shown for each column, and what conditions each visible row should satisfy.
Multiple aggregate statistics for an output variable can be shown at the same time, e.g., mean, standard deviation, median, min, max, mode, and count, where the variable's data type decides which statistics are available.
Any aggregate cell in the table can be inspected to trace records of individual runs that contribute to it.
When you find some rows shall be supported by more concrete data, new runs relevant to the particular rows can be planned directly from the table.

#### Chart
3X chart displays the data shown in the table as a two-dimensional figure.
Multiple input and output variables of interest can be chosen to automatically create a chart based on the type and range of the data.
When you specify more than two variables (for X and Y axes), 3X figures out which of the chosen variables map to a second Y axis or distinguish the series in the chart.
Currently, only line charts and scatter plots with simple options can be drawn.
Any visual element in these automatically generated charts are interactive, inviting you to inspect what runs have made up the data point and drill down to a more specific visualization.



<a name="further-reading"></a>
## Further Reading

### Installation Instructions
See [3X Installation Instructions](docs/install/) for quick instructions to download/build and install 3X on your systems.

### Tutorial for Getting Started
See [3X Tutorial with Step-through Examples](docs/tutorial/) for a step-by-step instructions using real examples.
By following the tutorial you can experience how powerful 3X is, and prepare yourself to organize your own computational experiments using 3X.



<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
