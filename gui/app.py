import json
import os
import sys
import subprocess
import yaml
from datetime import date, timedelta
from functools import wraps
from flask import (
    Flask, render_template, request, redirect,
    url_for, flash, session, jsonify,
)

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.pb_client import PocketBaseClient
from src.parser import parse_csv
from src.categorizer import Categorizer
from src.pb_deduplicator import PocketBaseDeduplicator
from src.pb_uploader import PocketBaseUploader
from src.pb_learner import PocketBaseLearner

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.path.join(BASE_DIR, 'config.yaml')
CATEGORIES_FILE = os.path.join(BASE_DIR, 'categories.json')
PENDING_FILE = os.path.join(BASE_DIR, 'data', 'pending_rules.json')
APPROVED_FILE = os.path.join(BASE_DIR, 'data', 'approved_rules.json')

app = Flask(__name__)


# ── Helpers ──────────────────────────────────────────────────────────────────

def load_config():
    with open(CONFIG_FILE, encoding='utf-8') as f:
        return yaml.safe_load(f)

def save_config(cfg):
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        yaml.dump(cfg, f, allow_unicode=True, default_flow_style=False)

def load_categories():
    if os.path.exists(CATEGORIES_FILE):
        with open(CATEGORIES_FILE, encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_categories(cats):
    with open(CATEGORIES_FILE, 'w', encoding='utf-8') as f:
        json.dump(cats, f, indent=2, ensure_ascii=False)

def load_pending():
    if os.path.exists(PENDING_FILE):
        with open(PENDING_FILE, encoding='utf-8') as f:
            return json.load(f)
    return []

def save_pending(pending):
    os.makedirs(os.path.dirname(PENDING_FILE), exist_ok=True)
    with open(PENDING_FILE, 'w', encoding='utf-8') as f:
        json.dump(pending, f, indent=2, ensure_ascii=False)

def load_approved():
    if os.path.exists(APPROVED_FILE):
        with open(APPROVED_FILE, encoding='utf-8') as f:
            return json.load(f)
    return []

def save_approved(approved):
    os.makedirs(os.path.dirname(APPROVED_FILE), exist_ok=True)
    with open(APPROVED_FILE, 'w', encoding='utf-8') as f:
        json.dump(approved, f, indent=2, ensure_ascii=False)

def period_dates(period):
    today = date.today()
    if period == 'this_month':
        return date(today.year, today.month, 1).isoformat(), None
    elif period == 'last_month':
        last = date(today.year, today.month, 1) - timedelta(days=1)
        return date(last.year, last.month, 1).isoformat(), last.isoformat()
    elif period == 'last_3m':
        m, y = today.month - 3, today.year
        if m <= 0: m += 12; y -= 1
        return date(y, m, 1).isoformat(), None
    elif period == 'last_6m':
        m, y = today.month - 6, today.year
        if m <= 0: m += 12; y -= 1
        return date(y, m, 1).isoformat(), None
    elif period == 'this_year':
        return date(today.year, 1, 1).isoformat(), None
    elif period == 'last_year':
        return date(today.year - 1, 1, 1).isoformat(), date(today.year - 1, 12, 31).isoformat()
    return None, None  # all time


def get_stats(cfg, since_date=None, until_date=None):
    pb = PocketBaseClient(cfg)
    expenses_by_cat = {}
    monthly = {}
    total_income = 0.0
    total_expense = 0.0

    filters = []
    if since_date:
        filters.append(f'date >= "{since_date}"')
    if until_date:
        filters.append(f'date <= "{until_date}"')

    base_params = {'perPage': 500, 'fields': 'amount,category,type,date'}
    if filters:
        base_params['filter'] = ' && '.join(filters)

    page = 1
    while True:
        data = pb.get('/api/collections/transactions/records',
                      params={**base_params, 'page': page}).json()
        for rec in data.get('items', []):
            amt = abs(rec.get('amount', 0) or 0)
            cat = rec.get('category', 'Uncategorized')
            tx_type = rec.get('type', 'Expense')
            month_key = (rec.get('date') or '')[:7]
            if tx_type == 'Expense':
                expenses_by_cat[cat] = expenses_by_cat.get(cat, 0) + amt
                total_expense += amt
            else:
                total_income += amt
            if month_key:
                m = monthly.setdefault(month_key, {'income': 0.0, 'expense': 0.0})
                if tx_type == 'Income':
                    m['income'] += amt
                else:
                    m['expense'] += amt
        if page >= data.get('totalPages', 1):
            break
        page += 1

    sorted_months = sorted(monthly.keys())
    net = round(total_income - total_expense, 2)
    savings_rate = round(net / total_income * 100, 1) if total_income > 0 else 0.0
    avg_monthly = round(total_expense / max(len(sorted_months), 1), 2)

    return {
        'expenses_by_cat': dict(
            sorted(expenses_by_cat.items(), key=lambda x: x[1], reverse=True)[:10]
        ),
        'monthly_labels': sorted_months,
        'monthly_income': [round(monthly[m]['income'], 2) for m in sorted_months],
        'monthly_expense': [round(monthly[m]['expense'], 2) for m in sorted_months],
        'net_savings': [round(monthly[m]['income'] - monthly[m]['expense'], 2) for m in sorted_months],
        'total_income': round(total_income, 2),
        'total_expense': round(total_expense, 2),
        'net': net,
        'savings_rate': savings_rate,
        'avg_monthly_expense': avg_monthly,
    }


# ── Auth ─────────────────────────────────────────────────────────────────────

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        cfg = load_config()
        pw = cfg.get('gui', {}).get('password', 'changeme')
        if request.form.get('password') == pw:
            session['logged_in'] = True
            return redirect(url_for('index'))
        flash('Wrong password.', 'danger')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route('/')
@login_required
def index():
    cfg = load_config()
    cats = load_categories()
    pending = load_pending()
    period = request.args.get('period', 'all')
    try:
        since, until = period_dates(period)
        stats = get_stats(cfg, since, until)
    except Exception:
        stats = None
    return render_template('index.html',
        config=cfg,
        category_count=len(cats),
        pending_count=len(pending),
        stats=stats,
        period=period,
    )


@app.route('/setup', methods=['GET', 'POST'])
@login_required
def setup():
    cfg = load_config()

    if request.method == 'POST':
        cfg.setdefault('google_drive', {})
        cfg.setdefault('notion', {})
        cfg.setdefault('email', {})
        cfg.setdefault('gui', {})

        cfg['google_drive']['folder_id'] = request.form.get('drive_folder_id', '').strip()
        cfg['notion']['token'] = request.form.get('notion_token', '').strip()
        cfg['email']['username'] = request.form.get('email_username', '').strip()
        cfg['email']['app_password'] = request.form.get('email_app_password', '').strip()
        cfg['email']['recipient'] = request.form.get('email_recipient', '').strip()
        cfg['poll_interval_minutes'] = int(request.form.get('poll_interval', 15))
        cfg['gui']['password'] = request.form.get('gui_password', 'changeme').strip()

        # Service account file upload
        sa_file = request.files.get('service_account')
        if sa_file and sa_file.filename:
            sa_path = os.path.join(BASE_DIR, 'config', 'service_account.json')
            os.makedirs(os.path.dirname(sa_path), exist_ok=True)
            sa_file.save(sa_path)
            cfg['google_drive']['service_account_file'] = 'config/service_account.json'
            flash('Service account file uploaded.', 'success')

        save_config(cfg)
        flash('Configuration saved.', 'success')
        return redirect(url_for('setup'))

    sa_exists = os.path.exists(
        os.path.join(BASE_DIR, cfg.get('google_drive', {}).get('service_account_file', ''))
    )
    return render_template('setup.html', config=cfg, sa_exists=sa_exists)


@app.route('/categories', methods=['GET', 'POST'])
@login_required
def categories():
    cats = load_categories()

    if request.method == 'POST':
        action = request.form.get('action')

        if action == 'save':
            new_cats = {}
            cat_names = request.form.getlist('cat_name')
            cat_keywords = request.form.getlist('cat_keywords')
            for name, kws in zip(cat_names, cat_keywords):
                name = name.strip()
                if name:
                    keywords = [k.strip() for k in kws.splitlines() if k.strip()]
                    new_cats[name] = keywords
            save_categories(new_cats)
            cats = new_cats
            flash('Categories saved.', 'success')

        elif action == 'add':
            new_name = request.form.get('new_cat_name', '').strip()
            if new_name and new_name not in cats:
                cats[new_name] = []
                save_categories(cats)
                flash(f'Category "{new_name}" added.', 'success')
            elif new_name in cats:
                flash(f'Category "{new_name}" already exists.', 'danger')

        elif action == 'delete':
            cat_to_delete = request.form.get('delete_cat', '').strip()
            if cat_to_delete in cats:
                del cats[cat_to_delete]
                save_categories(cats)
                flash(f'Deleted "{cat_to_delete}".', 'success')
            return redirect(url_for('categories'))

    return render_template('categories.html', categories=cats)


@app.route('/review', methods=['GET', 'POST'])
@login_required
def review():
    pending = load_pending()

    if request.method == 'POST':
        cats = load_categories()
        approved_ids = set(request.form.getlist('approve'))
        dismissed_ids = set(request.form.getlist('dismiss'))
        approved_archive = load_approved()

        for item in pending:
            pid = item['page_id']
            if pid in approved_ids:
                keyword = request.form.get(f'keyword_{pid}', item['keyword']).strip()
                category = request.form.get(f'category_{pid}', item['category']).strip() or item['category']
                if keyword and category:
                    cats.setdefault(category, [])
                    if keyword not in cats[category]:
                        cats[category].append(keyword)
                item['approved'] = True
                approved_archive.append({**item, 'keyword': keyword})
            elif pid in dismissed_ids:
                item['approved'] = True  # remove from pending without saving rule

        pending = [p for p in pending if not p.get('approved')]
        save_categories(cats)
        save_pending(pending)
        save_approved(approved_archive)
        flash('Rules updated.', 'success')
        return redirect(url_for('review'))

    approved = load_approved()
    cats = load_categories()
    return render_template('review.html', pending=pending, approved=approved, categories=list(cats.keys()))


@app.route('/upload', methods=['GET', 'POST'])
@login_required
def upload():
    if request.method == 'POST':
        f = request.files.get('csv_file')
        if not f or not f.filename:
            flash('No file selected.', 'danger')
            return redirect(url_for('upload'))

        cfg = load_config()
        content = f.read().decode('utf-8-sig')
        transactions = parse_csv(content)

        categorizer = Categorizer(CATEGORIES_FILE)
        categorized, uncategorized = categorizer.categorize(transactions)
        all_tx = categorized + uncategorized

        deduplicator = PocketBaseDeduplicator(cfg)
        new_tx = deduplicator.filter_new(all_tx)

        if not new_tx:
            flash('No new transactions found (all already imported).', 'info')
            return redirect(url_for('upload'))

        uploader = PocketBaseUploader(cfg)
        new_uncat = [tx for tx in new_tx if tx['category'] == 'Uncategorized']
        new_cat = [tx for tx in new_tx if tx['category'] != 'Uncategorized']

        uploader.upload(new_cat)
        if new_uncat:
            uploader.upload(new_uncat)

        learner = PocketBaseLearner(cfg)
        learner.scan_for_recategorized()

        flash(
            f'Imported {len(new_tx)} transactions '
            f'({len(new_cat)} categorized, {len(new_uncat)} uncategorized).',
            'success',
        )
        return redirect(url_for('upload'))

    return render_template('upload.html')


@app.route('/transactions')
@login_required
def transactions():
    cfg = load_config()
    pb = PocketBaseClient(cfg)

    page = int(request.args.get('page', 1))
    search = request.args.get('search', '').strip()
    cat_filter = request.args.get('category', '').strip()
    type_filter = request.args.get('type', '').strip()
    sort_by = request.args.get('sort_by', 'date')
    sort_order = request.args.get('sort_order', 'desc')

    valid_sorts = {'date', 'name', 'amount', 'category'}
    if sort_by not in valid_sorts:
        sort_by = 'date'
    pb_sort = f'{"-" if sort_order == "desc" else ""}{sort_by}'

    filters = []
    if search:
        filters.append(f'name~"{search}"')
    if cat_filter:
        filters.append(f'category="{cat_filter}"')
    if type_filter:
        filters.append(f'type="{type_filter}"')

    params = {
        'perPage': 50,
        'page': page,
        'sort': pb_sort,
        'fields': 'id,date,name,amount,currency,category,type',
    }
    if filters:
        params['filter'] = ' && '.join(filters)

    r = pb.get('/api/collections/transactions/records', params=params)
    data = r.json()

    cats = list(load_categories().keys())
    return render_template('transactions.html',
        records=data.get('items', []),
        total_pages=data.get('totalPages', 1),
        current_page=page,
        total=data.get('totalItems', 0),
        search=search,
        cat_filter=cat_filter,
        type_filter=type_filter,
        categories=cats,
        sort_by=sort_by,
        sort_order=sort_order,
    )


@app.route('/transactions/<record_id>/update', methods=['POST'])
@login_required
def update_transaction(record_id):
    cfg = load_config()
    pb = PocketBaseClient(cfg)
    category = request.form.get('category', '').strip()
    if category:
        pb.patch(f'/api/collections/transactions/records/{record_id}',
                 json={'category': category})
        try:
            PocketBaseLearner(cfg).scan_for_recategorized()
        except Exception:
            pass
    return redirect(request.referrer or url_for('transactions'))


@app.route('/run', methods=['POST'])
@login_required
def run_now():
    main_py = os.path.join(BASE_DIR, 'main.py')
    result = subprocess.run(
        [sys.executable, main_py, '--once'],
        capture_output=True, text=True, cwd=BASE_DIR
    )
    output = (result.stdout + result.stderr).strip()
    return render_template('run_result.html', output=output, returncode=result.returncode)


@app.route('/api/reset-rules', methods=['POST'])
def api_reset_rules():
    """Clear pending_rules.json so the autocategorizer starts fresh."""
    cleared = False
    if os.path.exists(PENDING_FILE):
        os.remove(PENDING_FILE)
        cleared = True
    return jsonify({'ok': True, 'cleared': cleared})


# ── Entry point ───────────────────────────────────────────────────────────────

def create_app():
    cfg = load_config()
    app.secret_key = cfg.get('gui', {}).get('secret_key', 'dev-secret')
    return app


if __name__ == '__main__':
    application = create_app()
    cfg = load_config()
    port = cfg.get('gui', {}).get('port', 5000)
    application.run(host='0.0.0.0', port=port, debug=True)
