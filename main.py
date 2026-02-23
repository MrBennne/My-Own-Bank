import time
import logging
import sys
import os
import yaml

from src.drive_watcher import DriveWatcher
from src.parser import parse_csv
from src.categorizer import Categorizer
from src.deduplicator import Deduplicator
from src.uploader import NotionUploader
from src.learner import Learner
from src.notifier import Notifier

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
)
log = logging.getLogger(__name__)


def load_config(path='config.yaml'):
    with open(path, encoding='utf-8') as f:
        return yaml.safe_load(f)


def process_files(config):
    watcher = DriveWatcher(config)
    categorizer = Categorizer(config.get('categories_file', 'categories.json'))
    deduplicator = Deduplicator(config)
    uploader = NotionUploader(config)
    learner = Learner(config)
    notifier = Notifier(config)

    files = watcher.get_new_files()
    if not files:
        log.info('No new files found.')
        return

    for filename, file_id, content in files:
        log.info(f'Processing: {filename}')
        try:
            transactions = parse_csv(content)
            log.info(f'  Parsed {len(transactions)} transactions')

            categorized, uncategorized = categorizer.categorize(transactions)
            log.info(f'  Categorized: {len(categorized)}, Uncategorized: {len(uncategorized)}')

            all_tx = categorized + uncategorized
            new_tx = deduplicator.filter_new(all_tx)
            log.info(f'  New after dedup: {len(new_tx)}')

            if new_tx:
                # Upload categorized and uncategorized separately so we can track IDs
                new_categorized = [tx for tx in new_tx if tx['category'] != 'Uncategorized']
                new_uncategorized = [tx for tx in new_tx if tx['category'] == 'Uncategorized']

                uploader.upload(new_categorized)

                if new_uncategorized:
                    uncat_ids = uploader.upload(new_uncategorized)
                    pairs = list(zip(uncat_ids, [t['name'] for t in new_uncategorized]))
                    learner.record_uploaded_uncategorized(pairs)
                    notifier.notify_uncategorized(new_uncategorized)
                    log.info(f'  Notified about {len(new_uncategorized)} uncategorized')

                log.info(f'  Uploaded {len(new_tx)} transactions to Notion')

            watcher.mark_processed(file_id)
            log.info(f'  Moved {filename} to processed/')

        except Exception as e:
            log.error(f'  Error processing {filename}: {e}', exc_info=True)

    # Check if any previously-uncategorized entries have been manually categorized in Notion
    log.info('Scanning Notion for newly categorized entries...')
    learner.scan_for_recategorized()


if __name__ == '__main__':
    config = load_config()
    os.makedirs(config.get('data_dir', 'data'), exist_ok=True)

    if '--once' in sys.argv:
        process_files(config)
    else:
        interval = config.get('poll_interval_minutes', 15) * 60
        log.info(f'Watcher started. Polling every {interval // 60} minutes.')
        while True:
            try:
                process_files(config)
            except Exception as e:
                log.error(f'Unhandled error: {e}', exc_info=True)
            time.sleep(interval)
