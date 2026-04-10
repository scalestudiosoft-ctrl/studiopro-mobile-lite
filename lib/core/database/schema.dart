const List<String> appSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS business_profile (
    business_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT NOT NULL,
    business_type TEXT NOT NULL,
    owner_name TEXT NOT NULL DEFAULT '',
    device_name TEXT NOT NULL DEFAULT 'Android',
    default_opening_cash REAL NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS workers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT,
    commission_type TEXT NOT NULL,
    commission_value REAL NOT NULL,
    active INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS clients (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS service_catalog (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    base_price REAL NOT NULL,
    active INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS appointments (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    client_name TEXT NOT NULL,
    worker_id TEXT,
    worker_name TEXT,
    service_code TEXT,
    service_name TEXT,
    scheduled_at TEXT NOT NULL,
    status TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS service_records (
    id TEXT PRIMARY KEY,
    performed_at TEXT NOT NULL,
    client_id TEXT NOT NULL,
    client_name TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    worker_name TEXT NOT NULL,
    service_code TEXT NOT NULL,
    service_name TEXT NOT NULL,
    unit_price REAL NOT NULL,
    payment_method TEXT NOT NULL,
    status TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sales (
    id TEXT PRIMARY KEY,
    sale_at TEXT NOT NULL,
    client_id TEXT NOT NULL,
    worker_id TEXT NOT NULL,
    service_record_id TEXT NOT NULL,
    net_total REAL NOT NULL,
    payment_method TEXT NOT NULL,
    payment_status TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS cash_movements (
    id TEXT PRIMARY KEY,
    movement_at TEXT NOT NULL,
    type TEXT NOT NULL,
    concept TEXT NOT NULL,
    amount REAL NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'efectivo',
    notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS cash_sessions (
    id TEXT PRIMARY KEY,
    work_date TEXT NOT NULL,
    opened_at TEXT NOT NULL,
    closed_at TEXT,
    opening_cash REAL NOT NULL,
    status TEXT NOT NULL,
    opened_by TEXT NOT NULL DEFAULT 'mobile_user',
    closing_notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS daily_closings (
    id TEXT PRIMARY KEY,
    work_date TEXT NOT NULL,
    opened_at TEXT NOT NULL,
    closed_at TEXT NOT NULL,
    opening_cash REAL NOT NULL,
    sales_total REAL NOT NULL,
    expenses_total REAL NOT NULL,
    expected_cash_closing REAL NOT NULL,
    export_file_name TEXT NOT NULL,
    closed_by TEXT NOT NULL DEFAULT 'mobile_user',
    notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS export_history (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    share_channel TEXT,
    close_id TEXT NOT NULL
  )
  ''',
  "ALTER TABLE business_profile ADD COLUMN owner_name TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE business_profile ADD COLUMN device_name TEXT NOT NULL DEFAULT 'Android'",
  "ALTER TABLE business_profile ADD COLUMN default_opening_cash REAL NOT NULL DEFAULT 0",
  "ALTER TABLE appointments ADD COLUMN client_name TEXT NOT NULL DEFAULT ''",
  "ALTER TABLE appointments ADD COLUMN worker_name TEXT",
  "ALTER TABLE appointments ADD COLUMN service_code TEXT",
  "ALTER TABLE appointments ADD COLUMN service_name TEXT",
  "ALTER TABLE cash_movements ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'efectivo'",
  '''
  CREATE TABLE IF NOT EXISTS cash_sessions (
    id TEXT PRIMARY KEY,
    work_date TEXT NOT NULL,
    opened_at TEXT NOT NULL,
    closed_at TEXT,
    opening_cash REAL NOT NULL,
    status TEXT NOT NULL,
    opened_by TEXT NOT NULL DEFAULT 'mobile_user',
    closing_notes TEXT NOT NULL DEFAULT ''
  )
  ''',
  "ALTER TABLE daily_closings ADD COLUMN closed_by TEXT NOT NULL DEFAULT 'mobile_user'",
  "ALTER TABLE daily_closings ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
];
