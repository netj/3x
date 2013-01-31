# TODOs

## Documentation
* intro of Concepts, Workflow

## CLI
* DONE change fancy printf stuffs done in exp-plan to `column -t`
* DONE exp-results
    * run restriction
    * condition restrcition
    * Consider using sqlite or relying on some relational store w/ SQL, i.e., don't be too fancy with the selection
* DONE exp-results bug fix for empty args
* DONE exp-results query on measurements (=/</>/<=/>=)
* DONE exp-plan with the output of exp-results query (e.g., when you want to rerun exps for certain conditions with failures/anomalies/etc.)
* DONE exp stop for stopping a running batch or run

* DONE separate the working directory for runs from other artifacts being assembled
    e.g., $EXPRUN/{args,env,measures/,stdin,stdout,stderr,...} $EXPRUN/cwd/{run,and all the other files of user's}

* DONE Commands for adding new ones for `exp conditions` and `exp measurements`
* Command for removing old ones for `exp conditions` and `exp measurements`

* DONE Make exp-findroot fail, i.e., EXPROOT=${EXPROOT:-$(exp-findroot)} instead of : ${EXPROOT:=$(exp-findroot)}
* Factorize EXPBATCH arg normalization

* DONE a simple way to bootstrap an exp repository

        exp setup  VAR1=V1,V2  VAR2=V3,V4..V5 ...  'COMMAND'  MEASURE1='PATT1_FROM_OUTPUT'  MEASURE2='PATT2_FROM_OUTPUT' ...

* keep links to currently running batch and/or run in a concentrated place, say `run/current/*` or so
* record observed real/user/sys times

* support exp setup --measurements pattern with more than one capture pattern

* `exp measure` for running newly added measures: requires partial assembly for exp.measure, and separating the running part from exp-run.
* exp-rerun for re-running past runs: do a copy --archive --link from the run dir and simply run it again?

* better messaging: let exp.sh dup terminal fds, so all msg can still reach the term

* DONE better hardlinking: first create a copy if necessary in .exp/ and hardlink that one so that user can modify anything outside run/ without worrying about overwriting all the snapshots.
* what if a file with same content has different perm mode? should we use name, perms, ... when archiving?

* enumerate dependencies, improve portability: readlink -f
    * column -t: bsdmainutils, http://www.cs.indiana.edu/~kinzler/align/

## GUI
* DONE chasis with express.js + node + bootstrap + coffee-script
* DONE workflow design

* DONE specifying the conditions of interest for planning and listing results
* tabulating results
    * DONE basic table
    * DONE w/ or w/o aggregation: avg, med, sum, min, max, ...
        * DONE choose aggregation function for each measurements
        * DONE aggregated values popup
    * DONE show all records if aggregation for run# is turned off
    * DONE number formatting
    * DONE numeric type cell align right
    * DONE different number precision for diff measurements (using mean of |fractional|s of the actual values)
    * DONE fill empty results for selected conditions
        * from the popup, let user easily add exp plans
    * DONE clear separation of split aggregation control and selection/filtering/projection of columns
        * aggregate/or not menuitem on conditions
        * aggregate/or not icon on table column header
        * enabled/or not menuitem on conditions
    * DONE show progress while doing ResultsTable.display
* DONE clean up navbar with scrollspy
* DONE Encapsulate with CoffeeScript classes

* DONE Title with .exp/description or basename of the $EXPROOT and ExpKitServiceBaseURL
* DONE ExpKitServiceBaseURL change option
* DONE allow multiple instances of GUI with diff port (pid file is the singleton enforcer right now)

* DONE batch page
    * DONE monitoring running state
    * DONE start/stop/resume

* list of runs and batches
    * DONE planning/altering a batch (mostly just ordering)
    * api for storing new/updated batch
    * make PlanTable selectable
    * and allow removal of the selected items
* DONE make title clearer

* DONE Handy way to generate condition combinations from the result table and add them to plan table
    * DONE minor: append the popover in the first or run# column to avoid glitches
    * DONE minor: scroll to bottom of plan after adding
    * Show hints on combinations of what will be added to plans from the
      popover, and only display when it will actuall add ones.

* DONE bug of plan table -> create batch -> 1 line less batch

* Keep track of the results table configuration, and allow user to go back/forth in history
* DONE Reload button for results table

* DONE Don't treat RUNID special anymore (always active)
* Selection(Filter) on measurements
* Show multiple columns of same measurement with diff aggregation in results table

* DONE Re-layout Results/Chart/Plan/Runs to minimize scrolls and make it look
  better, and look not so complicated by adding margin

* Unify the common dataTables UI stuffs into a single base class, e.g., "Reset Column Order"

* easy add/removal of condition values

* Charting
    * use d3 to plot results
    * invent an intuitive interaction for mapping column(condition) to x/y/series
    * predefined set of visualizations
        * bar chart
        * scatter plot
    * and probably a composite one
        * small multiple

* DONE Use WebSockets (socket.io) to notify changes to the run/batch status and deliver new results incrementally
    * SKIP Use fs.watch to monitor file changes
    * DONE Detect if new runs finish or start
    * DONE and simply deliver using the awesome socket.io library
    * SKIP watchr is good but generates spurious events when there's dangling symlink under watched dirs
* Incremental(more efficient)/Non-intrusive(more usable GUI) updates of batch progress and states

* Uniting runs in the results table
    * hint on what condition combination is running
    * and how many of them are running
    * update the table as new results get added

* run page
    * monitoring logs
    * better looking run summary page

* Use hash for representing GUI state as URL and using the browser history and back/forward

* DONE add right margin to icons in h2 instead of space

## Wild ideas
* temporal trends in runs
* approximation/prediction of measurements, i.e., measures without actual runs
* estimating time for a plan based on other runs: will need to keep track of
  wallclock time etc.
* concise way to specify parallel execution order in the plan
* automatic suggestion of representative condition values given a range, based
  on how each varies output (Ashish)
* Think about what's a good way to present measurement datum which is
  multi-dimensional itself, e.g., instead of summarizing the result of a run as
  a scalar value (N/O/I/R), there can be an image file of some scatterplot
  generated for each combination of condition params.  Maybe ExpKit can show
  these images in the results table, but there should be a simple/general way
  to do aggregation over these images.

<!--
vim:undofile
map <D-CR>  <C-\><C-N>:!make -C ~/2012/Projects/ExpKit install PREFIX=~<CR>:!cd ~/2012/Study/Giraph-vs-Socialite/graph-benchmarks; exp gui stop; exp gui start &<CR>
-->
