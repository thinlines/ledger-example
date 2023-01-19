#!/bin/bash

redo-ifchange $2.txt

paps $2.txt -o $3 --format=pdf --header --font="Monospace 10" 2>/dev/null
