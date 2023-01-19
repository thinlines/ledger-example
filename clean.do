#!/bin/bash

find import -name '*.journal' | xargs rm -f

find reports -name '*.txt' -or -name '*.pdf' | xargs rm -f
