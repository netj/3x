#!/usr/bin/env python

import networkx as nx
import pickle
import os

n = int(os.environ['n'])
p = float(os.environ['p'])

G = pickle.load(file("workdir/graph.pickle"))
Gcc=nx.connected_component_subgraphs(G)

# print some statistics of the connected components
ratio_denominator = float(n)
Gcc_sizes = [len(Gi) for Gi in Gcc if len(Gi) > 1]
print "Number of Components (non-singleton): "               ,            len(Gcc_sizes)
print "Number of Disconnected Nodes (singleton components): ", len(Gcc) - len(Gcc_sizes)
print "Component Sizes: "      , "\t".join(str(m)                         for m in Gcc_sizes)
print "Component Size Ratios: ", "\t".join("%f" % (m / ratio_denominator) for m in Gcc_sizes)
print
