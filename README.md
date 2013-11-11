# <i class="icon-beaker"></i> 3X
## A tool for eXecutable eXploratory eXperiments

3X is a tool for conducting computational experiments in a systematic way.
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

### How does 3X define a computational experiment?

Any computational experiment can be logically decomposed into three different parts.
As an example, let's consider an "empirical study of sorting algorithms' performance."

#### Program
*Program* is what you want to run for your experiment.
In our example, implementations of the different sorting algorithms, such as bubble sort, quick sort, merge sort, etc., as well as the code for measuring execution time and number of comparisons constitute the experiment program.

#### Inputs
*Inputs* are the parameters of your program that you want to vary between runs.
In our example, the size and characteristics of the input to the sorting algorithm, as well as which sorting algorithm to use are the experiment inputs.


#### Outputs
*Outputs* are the data you want to collect from each of your runs.
In our example, the time and numbers measured are the experiment outputs.



### How can you run experiments with 3X?

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



## Further Reading

* [Installation instruction](docs/install/)
* [Tutorial with step-through examples](docs/tutorial/)

<!--
* [Reference Manual](docs/manual/#readme)
-->

<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
