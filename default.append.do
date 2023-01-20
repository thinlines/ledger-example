#!/bin/bash

exec >&2

year=$2
importjnlfiles=$(find import -iname "$2*.journal")

cat include/{init,payee-aliases,payee-acct-mappings}.dat $2.journal $importjnlfiles > $3

if ledger -f $3.tmp --sort date --strict print > x; then
	mv x $2.journal
	rm $3.tmp
else
	notify-send "Build failed"
fi

