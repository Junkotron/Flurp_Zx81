#!/bin/sh


mkdir -p old

touch nowhining.asm nowhining~ nowhining.bin nowhining.xref


mv *.asm old/
mv *.bin old/
mv *.xref old/
mv *~ old/
