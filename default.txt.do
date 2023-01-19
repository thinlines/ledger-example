#!/bin/python

"""default.text.do

Generates text reports from a ledger file
"""

import re
import sys
from datetime import datetime
import subprocess
import textwrap
import tomli
import pprint


class Currency:
    def __init__(self, code, currencies):
        self.code = code
        self.symbol = currencies[code]


class RedoDocument:
    """An income or balance statement document being processed by redo"""

    def __init__(self):
        with open("config.toml", "rb") as f:
            self.conf = tomli.load(f)

        self.name = self.conf["name"]
        self.filename = sys.argv[1]
        self.noext = sys.argv[2]
        self.tmpfile = sys.argv[3]
        self.pricedb = self.conf["price_db"]
        self.year = self.getYear()
        self.report = self.getReport()
        self.endingDate = self.getEndingdate()
        self.journal = self.year + ".journal"
        self.baseCommand = [
            "/usr/bin/ledger",
            "-f", self.journal,
            "--price-db", self.pricedb,
            "-p", self.year,
            "bal"
        ]
        self.currency = self.getCurrency()
        self.reportCommands = self.getReportCommands()
        self.shouldExchange = self.checkExchange()
        self.totalCommand = self.getTotalCommand()

        introstring = "This document is the {} for {} for {} as of {}."
        self.intro = introstring.format(self.report["name"],
                                        self.name, self.year,
                                        self.endingDate)

        if self.currency and self.shouldExchange:
            self.intro += (" Amounts have been converted to"
                           f" {self.currency.code} at their prices at the"
                           " time of transaction.")
        elif self.currency:
            self.intro += (" This report is limited to transactions"
                           f" in {self.currency.code}.")
        self.intro = textwrap.fill(self.intro, 80)

        self.title = "{} for {}".format(self.report["name"].title(), self.year)
        self.title = self.title + "\n" + "=" * (len(self.title) + 2)

        self.reports = self.getReports()
        self.total = self.getTotal()

    def getReport(self):
        """This looks in the filename for the appropriate report type"""
        reports = self.conf["reports"]
        for report in reports:
            if report["type"] in self.filename:
                return report

    def getYear(self):
        """Set the year based on four digits in a row found in the filename"""
        try:
            srch = "([0-9]{4})"
            year = re.search(srch, self.filename).group(1)
            return year
        except Exception:
            raise Exception("Could not get year from filename")

    def getEndingdate(self):
        """Determine how to print the ending date for the report."""
        datefmt = "%-m/%-d/%y"
        if self.year != str(datetime.now().year):
            date = datetime.strptime(self.year + "-12-31", "%Y-%m-%d")
            return date.strftime(datefmt)
        else:
            return datetime.now().strftime(datefmt)

    def checkExchange(self):
        """Decides whether to exchange currencies or just limit them to
        the specified currency, if available"""
        match = re.search("-X-", self.filename)
        if match:
            self.baseCommand.extend(["-H", "-X", self.currency.symbol])
            return True
        elif self.currency:
            self.baseCommand.extend([
                "--limit", f"commodity == '{self.currency.symbol}'"
            ])
        return False

    def getCurrency(self):
        """If there's a currency in the target filename, set a variable
        so we can convert values to that currency in the report."""
        match = re.search("[A-Z]{3}", self.filename)
        if match:
            currency = self.filename[match.start():match.end()]
            return Currency(currency, self.config["currencies"])
        else:
            return None

    def getReportCommands(self):
        """Determines the appropriate commands by comparing the filename
        to a dictionary of commands. Sets the variable self.reportCommands as
        a dictionary of commands."""
        try:
            return self.report["cmds"]
        except KeyError as error:
            print("Unknown report type:", error, file=sys.stderr)

    def getTotalCommand(self):
        """Set the ledger command the generates the total for the report."""
        args = self.baseCommand[:]
        for reportname, command in self.reportCommands.items():
            args.extend(command)
        if "balance" in self.report["type"]:
            args.remove("--invert")
        return args

    def getReports(self):
        """Runs ledger to get the report data. Returns a dictionary of
        strings that contain the report data for each report."""
        output = {}
        for category, cmd in self.reportCommands.items():
            args = self.baseCommand[:]
            args.extend(cmd)
            proc = subprocess.run(args, capture_output=True)
            if not proc.stderr:
                output[category] = proc.stdout.decode()
            else:
                error = proc.stderr.decode()
                raise Exception("An error occurred with ledger:\n" + error)
        return output

    def getTotal(self):
        """Runs ledger to get the total. It combines the commands in
        self.reportCommands and looks for the total at the bottom,
        adding a nice label along the way. Returns a string."""
        label = self.report["bottom_line_label"]
        output = ""
        proc = subprocess.run(self.totalCommand, capture_output=True)
        if not proc.stderr:
            reachedTotal = False
            lines = proc.stdout.decode().splitlines()
            for line in lines:
                if "---" not in line and not reachedTotal:
                    continue
                elif "---" in line:
                    reachedTotal = True
                    output = "=" * len(line)
                    continue
                output = "\n".join([output, line])
            output += "  " + label
            return output
        else:
            error = proc.stderr.decode()
            raise Exception("An error occurred with ledger:\n" + error)

    def writeOutput(self):
        print(self.title)
        print("\n{}\n".format(self.intro))
        for reportname, report in self.reports.items():
            print(report)
        print(self.total)


def main():
    datafile = RedoDocument()

    datafile.writeOutput()


if __name__ == "__main__":
    main()
