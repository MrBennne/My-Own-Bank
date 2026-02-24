import time
import logging
import sys
import os
import yaml

from src.drive_watcher import DriveWatcher
from src.parser import parse_csv
from src.categorizer import Categorizer
from src.pb_deduplicator import PocketBaseDeduplicator
from src.pb_uploader import PocketBaseUploader
from src.pb_learner import PocketBaseLearner
from src.notifier import Notifier

os.makedirs('logs', exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('logs/pipeline.log', encoding='utf-8'),
    ],
)
log = logging.getLogger(__name__)


def load_config(path='config.yaml'):
    with open(path, encoding='utf-8') as f:
        return yaml.safe_load(f)


LOG_FILE = 'logs/pipeline.log'


def process_files(config):
    watcher = DriveWatcher(config)
    categorizer = Categorizer(config.get('categories_file', 'categories.json'))
    deduplicator = PocketBaseDeduplicator(config)
    uploader = PocketBaseUploader(config)
    learner = PocketBaseLearner(config)
    notifier = Notifier(config)

    files = watcher.get_new_files()
    if not files:
        log.info('No new files found.')
    else:
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

    # Always scan for newly categorized entries, even if no new files
    log.info('Scanning PocketBase for newly categorized entries...')
    learner.scan_for_recategorized()

    try:
        watcher.upload_log(LOG_FILE)
    except Exception as e:
        log.warning(f'Could not upload log to Drive: {e}')


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
