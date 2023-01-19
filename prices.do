#!/bin/bash

if [ ! "$YEAR" ]; then
	YEAR=$(date +%Y)
fi
if [ ! "$MONTH" ]; then
	MONTH=$(date +%m)
fi

usdcmd="pricehist fetch yahoo CNY=X -s $YEAR-$MONTH-01 -e today -o ledger"

swtsxcmd="pricehist fetch yahoo SWTSX -s $YEAR-$MONTH-01 -e today -o ledger"

cat \
	.pricedb \
	<($usdcmd | sed -e 's/CNY=X /$ ¥/' -e 's/ CNY$//') \
	<($swtsxcmd | sed -Ee 's/([0-9][0-9]?\.[0-9]+) USD/$\1/') \
	| sort -u > .pricedb.tmp

mv .pricedb.tmp .pricedb
