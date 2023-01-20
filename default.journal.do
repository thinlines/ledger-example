#!/bin/python

"""default.journal.do

This takes an input csv and processes it to produce a ledger-formatted
journal.
"""

import sys
import os
import re
import subprocess as sp
import BankCSV
from io import StringIO
try:
    import tomllib
except ModuleNotFoundError:
    import tomli


class InputFile:
    """A CSV file of financial data."""

    def __init__(self, baseName: str):
        """Take a filename and prepares it for input to ledger"""
        with open("config.toml", "rb") as f:
            self.conf = tomli.load(f)
        self.path = baseName + ".csv"
        self.year = re.search("([0-9]{4})", baseName).group(1)

        filetypes = [
            "alipay", "icbc", "bjb", "schwab", "wfcc", "wfchk", "wfsav"
        ]
        for filetype in filetypes:
            if filetype in self.path:
                self.filetype = filetype
                break
        if not self.filetype:
            raise Exception(f"Unknown filetype for {self.path}")
        try:
            self.acctInfo = next((acct for acct in self.conf["accounts"]
                                 if acct["folder"] == self.filetype), None)
            encoding = self.acctInfo.get("encoding", "utf-8")
        except AttributeError:
            msg = (f"Account {self.filetype} can't be found. Make sure the"
                   f" folder is set to {self.filetype} in config.toml")
            print(msg, file=sys.stderr)
            exit(1)

        with open(self.path, encoding=encoding) as f:
            lines = f.readlines()
            acct = next((acct for acct in self.conf["accounts"]
                         if acct["folder"] == self.filetype), None)
            headLength = acct.get("num_header_lines", 0)
            tailLength = acct.get("num_tail_lines", 0)
            headless = self.discardHeader(lines, headLength)
            if tailLength == 0:
                self.lines = headless
            else:
                self.lines = headless[:-tailLength]

    def discardHeader(self, list, NumLinesToDiscard):
        listIter = iter(list)
        counter = 0
        try:
            while counter < NumLinesToDiscard:
                next(listIter)
                counter += 1
            return [item for item in listIter]
        except StopIteration:
            msg = (f"Check your num_header_lines for account {self.filetype}."
                   " It seems to be longer than the CSV file!")
            print(msg, file=sys.stderr)
            exit(1)

    def __str__(self):
        return "".join(self.lines)


class OutputFile:
    """The final ledger document."""

    def __init__(self, target: str, basename: str, inputFile: InputFile):
        self.conf = inputFile.conf
        self.acctInfo = inputFile.acctInfo
        self.inputFilename = inputFile.path
        self.filetype = inputFile.filetype

        mainJournal = inputFile.year + ".journal"
        self.includes = self.conf["includes"]
        if os.path.exists(mainJournal):
            self.includes.append(mainJournal)
        else:
            raise Exception(f"{mainJournal} not found")

        self.csvDateFormat = self.acctInfo.get("CSV_date_format", None)
        self.account = self.acctInfo.get("name")
        self.inputData = str(inputFile).splitlines(keepends=True)
        self.processedData = self.processData(self.inputData)

    def processData(self, data):
        """Returns a list of dictionaries which can be printed by
        csv.DictWriter"""
        if self.filetype == "alipay":
            csvFile = BankCSV.AlipayCSV(data)
        elif self.filetype == "bjb":
            csvFile = BankCSV.BJBCSV(data)
        elif self.filetype == "icbc":
            csvFile = BankCSV.ICBCCSV(data)
        elif self.filetype == "schwab":
            csvFile = BankCSV.SchwabCSV(data)
        elif "wf" in self.filetype:
            csvFile = BankCSV.WellsFargoCSV(data)
        processedData = csvFile.processInput()
        out = StringIO()
        csvFile.writeOutput(out, processedData)
        return out.getvalue()

    def addOptions(self, list, option):
        """Adds a command line option before every item in given list"""
        for item in list:
            yield option
            yield item

    def writeOutput(self):
        ledgerCmd = [
            "/usr/bin/ledger",
            "--rich-data",
            "--invert",
            "--permissive",
            "--account", self.account,
            "convert",
            "/dev/stdin"
        ]
        if self.csvDateFormat:
            ledgerCmd.extend(["--input-date-format", self.csvDateFormat])
        incOpts = list(self.addOptions(self.includes, "-f"))
        ledgerCmd.extend(incOpts)
        proc = sp.run(ledgerCmd, encoding="utf-8", input=self.processedData,
                      capture_output=True)
        if proc.returncode:
            raise Exception(f"ledger crapped out:\n{proc.stderr}")
        if proc.stdout:
            print(proc.stdout)

    def redo_ifchange(self, files: list):
        """Run redo-ifchange on the list of files provided"""
        cmd = ["which", "redo"]
        redoBin = sp.run(cmd, capture_output=True).stdout.decode().strip()
        redoCmd = [redoBin] + files
        sp.run(redoCmd, close_fds=False)


def main():
    target = sys.argv[1]
    noext = sys.argv[2]

    inputFile = InputFile(noext)
    outputFile = OutputFile(target, noext, inputFile)
    outputFile.redo_ifchange(outputFile.includes)
    outputFile.writeOutput()


if __name__ == "__main__":
    main()
