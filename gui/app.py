import json
import os
import sys
import subprocess
import yaml
from functools import wraps
from flask import (
    Flask, render_template, request, redirect,
    url_for, flash, session,
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.path.join(BASE_DIR, 'config.yaml')
CATEGORIES_FILE = os.path.join(BASE_DIR, 'categories.json')
PENDING_FILE = os.path.join(BASE_DIR, 'data', 'pending_rules.json')

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
    return render_template('index.html',
        config=cfg,
        category_count=len(cats),
        pending_count=len(pending),
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

        for item in pending:
            pid = item['page_id']
            if pid in approved_ids:
                keyword = request.form.get(f'keyword_{pid}', item['keyword']).strip()
                category = item['category']
                if keyword and category:
                    cats.setdefault(category, [])
                    if keyword not in cats[category]:
                        cats[category].append(keyword)
                item['approved'] = True

        pending = [p for p in pending if not p.get('approved')]
        save_categories(cats)
        save_pending(pending)
        flash('Rules updated.', 'success')
        return redirect(url_for('review'))

    return render_template('review.html', pending=pending)


@app.route('/run', methods=['POST'])
@login_required
def run_now():
    main_py = os.path.join(BASE_DIR, 'main.py')
    subprocess.Popen([sys.executable, main_py, '--once'])
    flash('Processing started. Check server logs for progress.', 'success')
    return redirect(url_for('index'))


# ── Entry point ───────────────────────────────────────────────────────────────

def create_app():
    cfg = load_config()
    app.secret_key = cfg.get('gui', {}).get('secret_key', 'dev-secret')
    return app


if __name__ == '__main__':
    application = create_app()
    cfg = load_config()
    port = cfg.get('gui', {}).get('port', 5000)
    application.run(host='0.0.0.0', port=port, debug=False)
