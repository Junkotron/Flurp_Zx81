#!/bin/bash

./keysend "10 E"

for j in {A..Z}
do
    for i in {1..32}
    do
	echo "Welcome $j $i times"
	./keysend $j
    done
    if [ "$j" == "$1" ]; then 
	break
    fi
done

./keysend "^"
