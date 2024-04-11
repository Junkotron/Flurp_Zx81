#!/bin/sh


mkdir -p old

touch nowhining~

mv *~ old/

(cd asm ; ./clean.sh ; cd ..)
(cd speedloader ; ./clean.sh ; cd ..)
(cd ice40hx8k/ ; ./clean.sh ; cd ..)


