

I was inspired by [full-fledged-ledger][ffl] to manage my finances.
However, I preferred using `ledger` to `hledger` for several reasons:

[ffl]: https://github.com/adept/full-fledged-hledger/wiki

1. `ledger` is available on Android through Termux, though `hledger`
   isn't.  With no Haskell dependencies, I could take my finances on
   the road with me. In the big city I live in and with the job I have,
   this is a nice convenience to have.
2. Package dependencies for Haskell are numerous on Arch Linux so it made
   upgrading my system slower because of poor internet speed where I live.

After setting it all up and using it for about a year or two, I discovered
some drawbacks:

1. Commenting on and editing imported transactions is difficult.
2. Classifying and reconciling transactions is difficult to
   do. Personally, I had trouble using the scripting method described
   to speed up the process.
3. I rarely looked at the automatically generated reports, but each
   small change in the journal caused a lot of noise for each commit. I
   realized I would prefer to simply generate the reports manually when
   I wanted to look at them, or have a simpler format so there was less
   noise.

While I used it, I also never got 100% away from the hledger
dependency, so I wanted to finally sort that out.  The main obstacle
for this was figuring out how to convert the CSV files using just
ledger. Ledger has a `convert` command which does this, but it required
some scripting in order to prepare the CSV files for conversion.


## Requirements

PDF generation currently uses [paps](https://github.com/dov/paps) to
generate PDFs, although you could use enscript if you don't need UTF
currency symbols.

If you don't have Python 3.11, you'll need to `pip install tomli`.


## How to make it work

First, look at the config file. You'll need to create an account. Just
edit the example and delete any keys you don't need. Next, you'll need
to create a subclass of BankCSV (see BankCSV.py) to process the CSVs you
import from your bank. If you're lucky, it'll be as easy as just telling
which which columns the relevant info is located in. There are already
CSV processors defined for Alipay (China), Bank of Beijing, Industrial
and Commercial Bank of China (ICBC), Wells Fargo, and Schwab. A word
of warning: it helps to get these right the first time, because if you
change how the CSVs are output, the UUIDs will change and ledger will
think all your old transactions are new again.

Okay, so you have your CSV processing all set up? Great! A regular
importing process looks like this:

1. Download your CSVs.
2. Use meld or another diff program to integrate your bank CSV records
   into `${year}.0` file. You should have one CSV file per year.
3. Run `redo ${year}.append` to append new transactions to
   `${year}.journal`.
4. Run `redo` and you should get all your new reports. Voila!
5. By default, you'll get warnings for any accounts that you didn't
   define in init.dat. Go into `${year}.journal` and resolve those by
   either adding new aliases to include/aliases.dat or changing the
   accounts manually.
6. Add any comments manual transactions, etc. that you want to add. They
   will stay where they are when you import new transactions. Yay!

That's pretty much it. Good luck!
