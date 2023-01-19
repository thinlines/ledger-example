#!/bin/python

import glob
import re
import subprocess
import tomli

with open("config.toml", "rb") as f:
    config = tomli.load(f)

firstYear = config["first_year"]
currentYear = config["current_year"]
years = range(firstYear, currentYear + 1)
currencies = config["currencies"]
statements = [
    config["reports"][rpt]["type"] for rpt in range(len(config["reports"]))
]

reports = [
    "reports/" + str(year) + "-" + type + "-X-" + currency + ext
    for year in years
    for type in statements
    for currency in currencies.keys()
    for ext in [".txt", ".pdf"]
]

csvFiles = glob.glob("import/**/*.0", recursive=True)
journalImports = sorted(
    [re.sub(r"\.0", r".journal", file) for file in csvFiles
     for year in years if str(year) in file]
)

args = journalImports + reports
args.insert(0, "redo-ifchange")
subprocess.run(args, close_fds=False)
