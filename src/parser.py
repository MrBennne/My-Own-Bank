import csv
import re
import io
from datetime import datetime


def clean_name(raw_name):
    """Strip noise from raw bank merchant names."""
    name = raw_name.strip().strip('"')
    # Take text before first backslash (removes address parts)
    if '\\' in name:
        name = name.split('\\')[0].strip()
    # Remove reference numbers
    name = re.sub(r'\s+Notanr\s+\S+.*$', '', name, flags=re.IGNORECASE)
    name = re.sub(r'\s+Nota\s+nr\.\s+\S+.*$', '', name, flags=re.IGNORECASE)
    name = re.sub(r'\s+Trans\.nr\.\s+\S+.*$', '', name, flags=re.IGNORECASE)
    # Remove currency conversion notes
    name = re.sub(r'\s+beløb omregnet.*$', '', name, flags=re.IGNORECASE)
    return name.strip()


def parse_amount(amount_str):
    """Convert European number format to float.
    Examples: '-1.234,56' -> -1234.56  |  '-58,71' -> -58.71
    """
    s = amount_str.strip().strip('"')
    # Remove thousands separator (dot), replace decimal comma with dot
    s = s.replace('.', '').replace(',', '.')
    return float(s)


def parse_date(date_str):
    """Convert DD-MM-YYYY to ISO YYYY-MM-DD."""
    return datetime.strptime(date_str.strip(), '%d-%m-%Y').strftime('%Y-%m-%d')


def parse_csv(content):
    """Parse raw bank export CSV.

    Format: semicolon-delimited, no header row.
    Columns: Date;Merchant;Amount;Currency
    """
    transactions = []
    reader = csv.reader(io.StringIO(content), delimiter=';')

    for row in reader:
        if not row or len(row) < 4:
            continue
        try:
            date = parse_date(row[0])
            name = clean_name(row[1])
            amount = parse_amount(row[2])
            currency = row[3].strip()

            if not name:
                continue

            transactions.append({
                'date': date,
                'name': name,
                'amount': amount,
                'currency': currency,
                'account': 'Lønkonto',
            })
        except (ValueError, IndexError):
            continue

    return transactions
