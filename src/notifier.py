import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

NOTION_DB_URL = 'https://www.notion.so/3103379ef16a8155aedcd69e17d727d8?v=3103379ef16a805bbce3000c6dde09a1'


class Notifier:
    def __init__(self, config):
        self.cfg = config['email']

    def notify_uncategorized(self, transactions):
        if not transactions:
            return

        subject = f"[My-Own-Bank] {len(transactions)} uncategorized transaction(s) need review"

        rows = ''
        for tx in transactions:
            sign = '+' if tx['amount'] >= 0 else ''
            rows += (
                f"<tr>"
                f"<td>{tx['date']}</td>"
                f"<td>{tx['name']}</td>"
                f"<td style='text-align:right'>{sign}{tx['amount']:,.2f} {tx['currency']}</td>"
                f"</tr>"
            )

        html = f"""
        <html><body style="font-family: sans-serif; color: #333;">
        <h2 style="color:#c0392b;">Uncategorized Transactions</h2>
        <p>{len(transactions)} transaction(s) could not be categorized automatically
        and have been saved as <b>Uncategorized</b> in Notion.</p>

        <table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse; width:100%">
          <thead style="background:#f0f0f0">
            <tr><th>Date</th><th>Merchant</th><th>Amount</th></tr>
          </thead>
          <tbody>{rows}</tbody>
        </table>

        <p style="margin-top:20px">
          <a href="{NOTION_DB_URL}" style="background:#2ecc71;color:#fff;padding:10px 18px;text-decoration:none;border-radius:4px">
            Open Notion to categorize
          </a>
        </p>

        <p style="color:#888;font-size:0.9em">
          After categorizing in Notion, open the <b>Review Rules</b> page in the GUI
          to choose which merchant patterns to save for next time.
        </p>
        </body></html>
        """

        self._send(subject, html)

    def _send(self, subject, html):
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = self.cfg['username']
        msg['To'] = self.cfg['recipient']
        msg.attach(MIMEText(html, 'html'))

        with smtplib.SMTP(self.cfg['smtp_host'], self.cfg['smtp_port']) as server:
            server.ehlo()
            server.starttls()
            server.login(self.cfg['username'], self.cfg['app_password'])
            server.sendmail(self.cfg['username'], self.cfg['recipient'], msg.as_string())
