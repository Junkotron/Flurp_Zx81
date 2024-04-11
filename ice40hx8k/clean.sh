#!/bin/sh

make clean

mkdir -p old

touch nowhining~ nowhining.bin

mv *~ old/
mv *.bin old/

