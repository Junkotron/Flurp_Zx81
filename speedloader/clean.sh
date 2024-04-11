#!/bin/sh


rm -f speedloader regdump break binterm keysend

mkdir -p old

touch nowhining~
touch nowhining.bin

mv *~ old
mv *.bin old

