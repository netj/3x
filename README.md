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
Using 3X we can understand what's being explored much better with significantly less effort and greater confidence.


<!--

Computational experiments are everywhere these days.
As data and information abound at every corner of human activity, computational methods are becoming an integral part of our intellectual endeavor.
It became crucial nowadays not just for computer scientists or researchers who deal with computers, but also for all kinds of engineers, physical and life scientists, and even for social scientists to deal with series of experiments that crunch data to discover new knowledge.

However, computational experiments are frequently done in an ad-hoc manner, which seriously undermines their credibility as well as the experimenters' productivity.
Everyone writes his/her own set of scripts for partially automating the execution of runs and retrieval of results.
The produced logs and data are organized in some custom structure that might make sense only to those who are actively engaged in the experiment.
As the experiment evolves, or after a new person joins, or simply after some time passes, such brittle setup is almost always guaranteed to fall apart.
As code for the experiment evolves, its output format usually varies over time and these scripts must catch up with those changes and cope with existing data at the same time, quickly creating a huge maintenance burden.
Unless extraordinary rigor is put into what is often regarded as periphery to one's main problem, ad-hoc setups for experiments make it difficult to not only repeat the whole process but also observe interesting facts from the accumulated experimental results.

*3X* is a software tool that aims to introduce a systematic approach to computational experiments to improve their reliability, while increasing our productivity.
3X provides you a simple, yet flexible, standard structure to organize experiments.
Within such structure, it keeps track of all the detailed records of your runs in an obvious and efficient way, so that anyone can easily inspect individual traces and reproduce the results later.
It comes with a powerful graphical user interface (GUI) that not only visualizes the results of your experiment so far, but lets you also guide it towards a direction that needs more exploration interactively.
Since most of the functions regarding the management of experimental tasks and data are exposed transparently through its command-line interface (CLI), filesystem hierarchy and file formats.
It is very simple to plug existing systems to 3X and automate routine jobs on top of it.

Still, it is very important to understand that conducting a reliable computational experiment remains a challenging problem no matter how advanced the tool you use is.
3X is not a magical tool that automatically systematizes your experiment.
Although it provides important scaffoldings on which you can construct reliable experiments more easily, the credibility of the experiment is ultimately up to how much rigor the experimenter puts into it.
Our hope in building 3X with standard structure and common vocabulary is to make establishing a principle become much easier, and practicing it be less burdensome.

-->

In the following sections, we define terms and concepts used by 3X, and describe what the workflow will be like to use 3X to run, explore, and analyze your own experiments.

### How do I start organizing a computational experiment with 3X?

Any computational experiment can be logically decomposed into three different parts: program, inputs, and outputs.
Each of these parts can be organized clearly in a dedicated space managed by 3X.
As an example, let's consider an "empirical study of sorting algorithms' time complexity" in the rest of this section.

#### Experiment Repository
An *experiment repository* is where 3X keeps all data related to an experiment.
It is an ordinary filesystem directory dedicated to your experiment, where you can organize your own files for the experiment under 3X's standard structure.
New experiment repositories can be easily created with a single command (`3x setup`).

#### Program
*Program* is what you want to run (or execute) to do the computation for your experiment.
In our example, implementations of the different sorting algorithms, such as bubble sort, quick sort, merge sort, etc., as well as the code for measuring execution time and number of comparisons constitute the experiment program.
Most program will output computed data as files or standard output/error based on the input you give, and can be thought as a function.
But 3X works fine with programs that have randomness in them producing different results on every runs even with the same input, or programs that mutate state of external systems, e.g., databases.
As long as there is a way to invoke your program from the command-line, 3X is agnostic to what programming language or programming system you used.
For example, you can use 3X to play with small Python scripts on your laptop, to run MATLAB/Octave code on your compute cluster, or to launch complex jobs on your Hadoop cluster.

#### Inputs
*Inputs* are what you want to vary between executions of your program.
In our example, the size and characteristics of the input to the sorting algorithm, as well as which sorting algorithm to use are the experiment inputs.
You can specify a finite set of discrete, symbolic values for each experiment input, e.g., `insertionSort`, `quickSort`, and `mergeSort`, etc. for input `algo` that decides which sorting algorithm to use.
3X supplies values for the inputs to your experiment program in the form of environment variables.
A filesystem directory is provided for each experiment input and each value of it to let you organize relevant input files in a manifest way.

#### Outputs
*Outputs* are what you want to extract from the result of each execution of your program.
In our example, the time and numbers measured are the experiment outputs.
3X lets you specify a set of regular expressions to extract pieces of text from the standard output and error of your experiment program.
If an output of your experiment is an image file, you can specify the filename as well.
In fact, this phase of extracting data for experiment outputs is entirely extensible, not limiting you to these built-in options.
You can use another set of your own programs, called *extractors*, to perform various computations that can be much more complex than simply searching for pieces of text or files, on the data produced by your original experiment program.


### How do I execute experiments with 3X?

Once you have a well-defined computational experiment, 3X provides powerful tools to plan, control, and manage its execution.
You can easily generate a combination of value bindings for the inputs from a selected set of values, and order them in a way you want to execute.
3X can execute your program on your local machine or a remote host via SSH one at a time, or on a cluster of machines in parallel.

#### Run
A *run* is a unit of single execution of your experiment program given the bindings of a value for each of your inputs.
State of each run is one among `PLANNED`, `RUNNING`, `ABORTED`, `FAILED`, or `DONE`, depending on whether it is to be executed, is executing, or was executed.
Every run gets a unique *run identifier* (`run#`) assigned once it starts execution, i.e., all runs except the `PLANNED` ones have unique run identifiers.
The *run directory*, whose path relative to the repository root is the run identifier, records all data that goes into and comes out of the single execution of that run.

#### Queue
*Queue* is a list of runs where 3X keeps track of its execution order of the remaining `PLANNED` runs and the history of finished runs.
It is the point of control of execution, and multiple queues can be used to organize runs into smaller groups.
You can *start a queue* to execute runs that have been or will be added to the queue, and *stop the queue* to abort any executing runs in it.

#### Target
*Target* defines where and under what environment your runs will execute.
Each queue has an associated target where its `PLANNED` runs will be sent for execution.
For example, you can tie one queue to a target for your local machine and another queue to a target for a remote machine, then execute different groups of runs on these two targets.






## Further Reading

* [Installation instruction](docs/install/)
* [Tutorial with step-through examples](docs/tutorial/)

<!--
* [Reference Manual](docs/manual/#readme)
-->

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
