This is the reference implementation of Powell's NEWUOA algorithm described in

M. J. D. Powell, The NEWUOA software for unconstrained optimization without derivatives,
In Large-Scale Nonlinear Optimization, eds. G. Di Pillo and M. Roma, pages 255--297, Springer,
New York, US, 2006

Coded by Zaikun ZHANG (www.zhangzk.net) based on the above-mentioned paper and Powell's code, with
modernization, bug fixes, and improvements.

Due to the dependency among the modules, the files must be compiled in the order indicated in
ffiles.txt. Before that, one must compile the Fortran files in the directory "common" according
to the ffiles.txt therein.

See the directory "examples" for an illustration about how to call the solver.

Dedicated to late Professor M. J. D. Powell FRS (1936--2015).

Started in July 2020.
