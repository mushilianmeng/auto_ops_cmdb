# AGENTS.md

## Cursor Cloud specific instructions

This is `auto_ops_cmdb` — a Django 3.2 CMDB / ops-management system whose entire UI is the
Django admin (themed with `django-simpleui`, in Chinese). Apps: `assets` (资产管理),
`alarm` (告警), `ci_cd` (持续发布), `log`. There is no separate frontend; everything is
served by the single Django dev server.

### Database (MariaDB) — must be started each session
The app requires a MySQL-compatible DB (MariaDB is installed). The service is **not**
managed by systemd here, so start it manually at the beginning of a session:

```
sudo service mariadb start
```

- DB name `auto_ops_cmdb`, accessed over TCP at `127.0.0.1:3306` as user `cmdb` / password
  `cmdb123` (configured in `mysite/settings.py`). The matching MariaDB user and the schema
  are already created in the VM snapshot.
- The DB was seeded once from `install/auto_ops_cmdb.sql` (full schema + data, incl. the
  admin account). Do NOT re-import it unless the schema is missing — re-importing wipes data.
  To recreate from scratch:
  `sudo mysql -e "CREATE DATABASE IF NOT EXISTS auto_ops_cmdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"`
  then `sudo mysql auto_ops_cmdb < install/auto_ops_cmdb.sql`.
- All Django migrations are recorded as applied in the seeded `django_migrations` table, so do
  NOT run `makemigrations`/`migrate` — the schema comes from the SQL dump, and some models are
  `managed = False`.

### MySQL driver
The `log/__init__.py` app module calls `pymysql.install_as_MySQLdb()`, so the project uses the
pure-Python `pymysql` as its `MySQLdb`. `mysqlclient` is NOT needed (avoid it — it requires
compilation).

### Running the app
Use the venv at `.venv` (created by the update script):

```
source .venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

Then open http://127.0.0.1:8000/admin/ — login `admin` / `admin`.
`DEBUG=True` and the logging config echoes every SQL query to the console; this is expected
and can be noisy.

### Lint / test
- Lint / config check: `python manage.py check` (a single harmless `urls.W005` warning about a
  duplicate `admin` namespace is expected — `mysite/urls.py` maps both `''` and `admin/` to the
  admin site).
- `python manage.py test` runs, but the repo ships only empty `tests.py` stubs, so no tests run.
