#!/bin/python

"""BankCSV.py

This module provides classes to process CSVs from each of the
financial institutions I import data from. BankCSV provides a
template class upon which the others are based.
"""

import csv
import sys
import re


class BankCSV:
    """A CSV of transactions."""

    def __init__(self, data):
        self.currency = "CNY"
        self.data = data
        self.origHeader = []
        self.header = [
            "date",
            "code",
            "description",
            "amount",
            "total",
            "note"
        ]

    def getLines(self):
        """Reads the input data and returns list of dicts, one for each row"""
        reader = csv.DictReader(self.data, self.origHeader)
        lines = [line for line in reader]
        return lines

    def getWriter(self, target):
        """Returns a csv.DictWriter to write the output to target"""
        return csv.DictWriter(
            target, extrasaction="ignore", fieldnames=self.header,
        )

    def getNote(self, row):
        print("You're printing a note without a proper def", file=sys.stderr)
        return None

    def getDate(self, row):
        pass

    def getCode(self, row):
        pass

    def getDescription(self, row):
        pass

    def getAmount(self, row):
        pass

    def getTotal(self, row):
        pass

    def getSymbol(self, row):
        pass

    def getPrice(self, row):
        pass

    def processInput(self):
        """Returns a list of dictionaries for each row in the input file.
        Note there is no header and the order of lines is unchanged from the
        original file, i.e. you may want to reverse the order when writing
        output because the order is usually newest to oldest transaction
        (which interferes with ledger's balance assertions)."""
        lines = []
        for row in self.lines:
            outputRow = {}
            outputRow["date"] = self.getDate(row)
            outputRow["code"] = self.getCode(row)
            outputRow["description"] = self.getDescription(row)
            outputRow["amount"] = self.getAmount(row)
            outputRow["total"] = self.getTotal(row)
            outputRow["note"] = self.getNote(row)
            outputRow["symbol"] = self.getSymbol(row)
            outputRow["price"] = self.getPrice(row)
            lines.append(outputRow)
        return lines

    def writeOutput(self, target, processedData):
        """Writes the processed CSV to target. Any items not defined in
        the header are ignored."""
        writer = self.getWriter(target)
        writer.writeheader()
        for row in reversed(processedData):
            writer.writerow(row)


class AlipayCSV(BankCSV):
    """A CSV of transactions from Alipay"""

    def __init__(self, data):
        super().__init__(data)
        self.currency = "CNY"
        self.origHeader = [
            "流水号",
            "时间",
            "名称",
            "备注",
            "收入",
            "支出",
            "账户余额（元）",
            "资金渠道"
        ]
        self.lines = self.getLines()

    def getDate(self, row):
        return row["时间"][:10]

    def getCode(self, row):
        return row["流水号"].strip()

    def getDescription(self, row):
        return row["名称"].strip()

    def getNote(self, row):
        return None

    def getAmount(self, row):
        return row["收入"].strip() + row["支出"].strip() + self.currency

    def getTotal(self, row):
        return row["账户余额（元）"].strip() + self.currency


class BJBCSV(BankCSV):
    """A CSV of transactions from Beijing Bank"""

    def __init__(self, data):
        super().__init__(data)
        self.currency = "CNY"
        self.origHeader = [
            "序号",
            "交易日期",
            "摘要",
            "收入/支出",
            "交易金额",
            "余额",
            "交易地点"
        ]
        self.lines = self.getLines()

    def getDate(self, row):
        return row["交易日期"]

    def getCode(self, row):
        return row["摘要"]

    def getDescription(self, row):
        return f'{row["摘要"]} {row["交易地点"]}'

    def getNote(self, row):
        return None

    def getAmount(self, row):
        if row["收入/支出"] == '转入':
            amount = f'{row["交易金额"]} {self.currency}'
        elif row["收入/支出"] == '支取':
            amount = f'-{row["交易金额"]} {self.currency}'
        return amount

    def getTotal(self, row):
        return f'{row["余额"]} {self.currency}'


class ICBCCSV(BankCSV):
    """A CSV of transactions from ICBC"""

    def __init__(self, data):
        super().__init__(data)
        self.currency = None
        self.origHeader = [
            "交易日期",
            "摘要",
            "交易场所",
            "交易国家或地区简称",
            "钞/汇",
            "交易金额(收入)",
            "交易金额(支出)",
            "交易币种",
            "记账金额(收入)",
            "记账金额(支出)",
            "记账币种",
            "余额",
            "对方户名"
        ]
        self.lines = self.getLines()

    def getDate(self, row):
        return row["交易日期"].strip()

    def getCode(self, row):
        return row["摘要"].strip()

    def getDescription(self, row):
        return row["交易场所"].strip() + ' ' + row["对方户名"].strip()

    def getAmount(self, row):
        currency = self.getCurrency(row)
        amtout = row["记账金额(支出)"].strip()
        amtin = row["记账金额(收入)"].strip()
        if amtout:
            return '-' + amtout + currency
        elif amtin:
            return amtin + currency

    def getTotal(self, row):
        currency = self.getCurrency(row)
        return row["余额"].strip() + currency

    def getNote(self, row):
        return None

    def getCurrency(self, row):
        currency = row["记账币种"].strip()
        if currency == u"美元":
            currency = "USD"
        else:
            currency = "CNY"
        return currency


class SchwabCSV(BankCSV):
    """A CSV of transactions from Schwab"""

    def __init__(self, data):
        super().__init__(data)
        self.dateFmt = "[0-9]{2}/[0-9]{2}/[0-9]{4}"
        self.currency = ""
        self.origHeader = [
            "Date",
            "Action",
            "Symbol",
            "Description",
            "Quantity",
            "Price",
            "Fees & Comm",
            "Amount"
        ]
        self.header.extend([
            "symbol",
            "price"
        ])
        self.lines = self.getLines()

    def getDate(self, row):
        if "as of" in row["Date"]:
            searchstring = f'({self.dateFmt}) as of ({self.dateFmt})'
            match = re.search(searchstring, row["Date"])
            date = match.group(2)
        else:
            date = row["Date"]
        return date

    def getCode(self, row):
        return row["Action"]

    def getDescription(self, row):
        return row["Description"]

    def getAmount(self, row):
        if self.getSymbol(row) and "Dividend" not in row["Action"]:
            amount = f'{row["Quantity"]} {row["Symbol"]} @@ {row["Amount"]}'
        else:
            amount = row["Amount"]
        return amount

    def getTotal(self, row):
        return None

    def getNote(self, row):
        if "as of" in row["Date"]:
            searchstring = f'({self.dateFmt}) as of {self.dateFmt}'
            match = re.search(searchstring, row["Date"])
            note = f'[={match.group(1)}], date: {match.group(1)}'
            return note

    def getSymbol(self, row):
        return row["Symbol"] or None

    def getPrice(self, row):
        return row["Price"] or None


class WellsFargoCSV(BankCSV):
    """A CSV of transactions from Wells Fargo"""

    def __init__(self, data):
        super().__init__(data)
        self.origHeader = [
            "date",
            "amount",
            "cleared",
            "note",
            "description"
        ]
        self.lines = self.getLines()
        self.currency = "$"

    def getDate(self, row):
        return row["date"]

    def getCode(self, row):
        desc = row["description"]
        if "REF #" in desc:
            code = re.search('REF #([A-Z0-9]+)', desc).group(1)
        else:
            code = ''
        return code

    def getDescription(self, row):
        return row["description"]

    def getAmount(self, row):
        return self.currency + row["amount"]

    def getNote(self, row):
        return row["note"]

    def getTotal(self, row):
        pass


if __name__ == "__main__":
    ftype = sys.argv[1]
    data = sys.stdin.readlines()
    if ftype == "alipay":
        csvFile = AlipayCSV(data)
    elif ftype == "bjb":
        csvFile = BJBCSV(data)
    elif ftype == "icbc":
        csvFile = ICBCCSV(data)
    elif ftype == "schwab":
        csvFile = SchwabCSV(data)
    elif "wf" in ftype:
        csvFile = WellsFargoCSV(data)

    processedData = csvFile.processInput()
    csvFile.writeOutput(sys.stdout, processedData)
