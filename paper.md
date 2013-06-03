PAPER CONTENTS
==============

Introduction etc
----------------



Simulation tool
-------------------

Environment
  
  Map. Contains APs. Allows scanning of signals at any location.

  Access Point Behaviour
    - Signal Reception -> figure 2 from http://research.microsoft.com/en-us/um/people/jckrumm/publications%202005/irs-tr-05-003.pdf
    - Signal Strength 
      - Power Level -> http://research.microsoft.com/en-us/um/people/jckrumm/publications%202005/irs-tr-05-003.pdf
      - Randomization -> http://gicl.cs.drexel.edu/people/regli/Classes/CS680/Papers/Localization/01331706.pdf
    - Density -> Table 2 from https://smartech.gatech.edu/bitstream/handle/1853/13177/git-cercs-06-10.pdf

Algorithms
  - Centroid
  - Fingerprinting

Testing method
  - Access Point Placement (with given mapsize, density)
  - Initial measurement (with given accuracy)
  - Iteration
    - Control measurement (only within the boundary, with given accuracy)
    - Log results
    - Replace (200/iterations)% of APs at random


Test Results
------------



Conclusion
----------