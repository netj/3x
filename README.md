# <i class="icon-beaker"></i> 3X
## A tool for eXecutable eXploratory eXperiments

Computational experiments are everywhere these days.  As data and information
abound at every corner of human activity, computational methods are becoming
an integral part of our intellectual endeavor.  It became crucial nowadays not
just for computer scientists or researchers who deal with computers, but also
for all kinds of engineers, physical and life scientists, and even for social
scientists to deal with series of experiments that crunch data to discover new
knowledge.

However, computational experiments are frequently done in an ad-hoc manner,
which seriously undermines their credibility as well as the experimenters'
productivity.  Everyone writes his/her own set of scripts for partially
automating the execution of runs and retrieval of results.  The produced logs
and data are organized in some custom structure that might make sense only to
those who are actively engaged in the experiment.  As the experiment evolves,
or after a new person joins, or simply after some time passes, such brittle
setup is almost always guaranteed to fall apart.
As code for the experiment evolves, its output format usually varies over time
and these scripts must catch up with those changes and cope with existing data
at the same time, quickly creating a huge maintenance burden.  Unless
extraordinary rigor is put into what is often regarded as periphery to one's
main problem, ad-hoc setups for experiments make it difficult to not only
repeat the whole process but also observe interesting facts from the
accumulated experimental results.

*3X* is a software tool that aims to introduce a systematic approach to
computational experiments to improve their reliability, while increasing
our productivity.  3X provides you a simple, yet flexible, standard
structure to organize experiments.  Within such structure, it keeps track
of all the detailed records of your runs in an obvious and efficient way, so
that anyone can easily inspect individual traces and reproduce the results
later.  It comes with a powerful graphical user interface (GUI) that not only
visualizes the results of your experiment so far, but lets you also guide it
towards a direction that needs more exploration interactively.  Since most of
the functions regarding the management of experimental tasks and data are
exposed transparently through its command-line interface (CLI), filesystem
hierarchy and file formats.  It is very simple to plug existing systems to 3X
and automate routine jobs on top of it.

Still, it is very important to understand that conducting a reliable
computational experiment remains a challenging problem no matter how advanced
the tool you use is.  3X is not a magical tool that automatically systematizes
your experiment.  Although it provides important scaffoldings on which you can
construct reliable experiments more easily, the credibility of the experiment
is ultimately up to how much rigor the experimenter puts into it.  Our hope in
building 3X with standard structure and common vocabulary is to make
establishing a principle become much easier, and practicing it be less
burdensome.


<!--
## Overview of 3X Concepts and Functionality

To give you a clear picture of what 3X provides, let's go through several
questions using a concrete example of "comparing performance of different
sorting algorithms."

### What is a computational experiment?

Any computational experiment can be logically decomposed into three different
parts:

<dl>

<dt>Program</dt>
<dd>
This is what you want to run for your experiment.  In our example,
implementations of the different sorting algorithms will belong here, such as
bubble sort, quick sort, ...
</dd>

<dt>Input Variables</dt>
<dd>
These are the parameters of your program that you want to vary between runs.
</dd>

<dt>Output Variables</dt>
<dd>
These are what you want to collect back from each run of your program.
</dd>

</dl>

3X provides a well-defined structure for you to factor your experiment into
these three different categories.


### How would you want to run them?

<dl>

<dt>Queue</dt>
<dd>
...
</dd>

<dt>Target</dt>
<dd>
... 
</dd>

<dt>Run</dt>
<dd>
... 
</dd>

</dl>

### Workflow

1. 


## FAQ

...
-->


## Further Reading

* [Installation instruction](docs/install/)
* [Tutorial with step-through examples](docs/tutorial/)

<!--
* [Reference Manual](docs/manual/#readme)
-->

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
