"""One-time backfill: set Type = Income/Expense on all existing Notion transactions."""
import yaml
from notion_client import Client

with open('config.yaml') as f:
    config = yaml.safe_load(f)

client = Client(auth=config['notion']['token'])
db_id = config['notion']['database_id']

# Ensure Type property exists
db = client.databases.retrieve(database_id=db_id)
if 'Type' not in db['properties']:
    client.databases.update(database_id=db_id, properties={'Type': {'select': {}}})
    print("Created 'Type' property in database")

# Page through all entries
cursor = None
updated = skipped = 0

while True:
    kwargs = {'database_id': db_id, 'page_size': 100}
    if cursor:
        kwargs['start_cursor'] = cursor
    resp = client.databases.query(**kwargs)

    for page in resp['results']:
        props = page['properties']
        existing_type = props.get('Type', {}).get('select')
        if existing_type:
            skipped += 1
            continue

        amount = props.get('Amount', {}).get('number')
        tx_type = 'Income' if (amount is not None and amount >= 0) else 'Expense'

        client.pages.update(
            page_id=page['id'],
            properties={'Type': {'select': {'name': tx_type}}},
        )
        updated += 1
        print(f"  Updated page {page['id'][:8]}... -> {tx_type}")

    if not resp.get('has_more'):
        break
    cursor = resp['next_cursor']

print(f"\nDone. Updated: {updated}, already had Type: {skipped}")
