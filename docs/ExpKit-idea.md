# "TestKit" idea

## Motivation
Running a large number of compute experiments on multiple different systems,
with different inputs varying several parameters, and all in a systematic way
isn't trivial.  I wanted to have a simple yet sophisticated enough tool,
or framework?, practice?, or whatever that I could reuse over time.

To record the actual motivating example of mine, I was testing graph algorithms
implemented in several different ways, namely, Socialite, Giraph, GPS, PBGL,
... and wanted to do the job in a better way than running everything manually.
There was a constant need of adding new input data, new implementations as well
as improvements to the existing ones.  I wanted all the experiments to be
reproducable by anyone (including myself) and easily repeatable so I can try
new ideas and get feedback without much effort.


## Requirements

### Input
* There are multiple source of input.
    * input files or arguments
    * environment variables

* It should be easy to group and denote an input set.

* Maybe extensible is better, meaning to define a new input set, it should be
    able to inherit/extend others instead of always starting from scratch.

* Each input set has a corresponding expected output.

* *inputs* repository will contain all the input sets, and each input set will
    reside in a directory.  All the derivations of an input set will be a
    subdirectory and nested in it.


### Execution
* It should be possible to write something like a one-liner shell script driver
    to plug the system under test and get things working.

* Yet, it should be flexible enough so the driver could grow into something
    pretty sophisticated.

* The driver will receive an input set, or start within the directory/env of an
    input set and should translate the input elements into an appropriate form
    for the system under test.  I guess it will start under a run directory
    (which is uniquely created every time for recording the logs and output)
    and the inputs will get passed over some environment variables.

* After the driver finishes its execution, it should be collecting the outputs
    and logs in the run directory for further inspection, collecting
    metrics, and judging correctness of the system under test.

* Each system under test will have a simple name, and with its driver and other
    related files, it will reside in a directory under its name in the *systems*
    repository.


### Measurement (Non-Functional)
* Performance Metrics
    * Time - CPU, Wallclock, ...
    * Space - Memory

* There could be arbitrary number of metrics each system would want to output.
    It should be able to record these and handle them well for later queries.


### Correctness (Functional)

#### Output

#### Expected Output
* 

#### Oracle
* 

#### Judge
* Each input set will contain a *judge* executable that accepts two path
    arguments to the actual output and its expected one so it can compare



### Summary
* It should have some plotting capabilities to let me instantly get a sense of
    how the runs went.



## Key Goals
* reproducible runs
    * record everything
    * and make the record standalone so it could be even rerunnable unless there's an inherent external dependency
* easy combination of input variables
    * and scheduling of them
* multiple output variables
    * performance stats (time, memory, ...)
    * correctness stats (error, ...)



## References
* [Criterion](http://bos.github.com/criterion/)
