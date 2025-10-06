import re
import sys
import time
from datetime import datetime, timedelta
from collections import defaultdict

if len(sys.argv) < 2:
    print("Использование: python dns_parser.py <путь_к_файлу> [--domains anydesk,rustdesk] [--time 1d|3d|1w] [--debug]")
    sys.exit(1)

# --- Парсинг аргументов ---
args = sys.argv[1:]
debug = False
time_filter = None
domains = []

if "--debug" in args:
    debug = True
    args.remove("--debug")

if "--time" in args:
    idx = args.index("--time")
    if idx + 1 < len(args):
        time_filter = args[idx + 1]
        del args[idx:idx + 2]
    else:
        print("❌ Ошибка: после --time нужно указать значение, например 1d или 1w")
        sys.exit(1)

if "--domains" in args:
    idx = args.index("--domains")
    if idx + 1 < len(args):
        domains = [d.strip().lower() for d in args[idx + 1].split(",") if d.strip()]
        del args[idx:idx + 2]
    else:
        print("❌ Ошибка: после --domains нужно указать список через запятую")
        sys.exit(1)

# Первый позиционный аргумент — путь к файлу
if not args:
    print("❌ Ошибка: не указан путь к файлу логов")
    sys.exit(1)
file_path = args[0]

if not domains:
    print("❌ Ошибка: не указаны домены (--domains anydesk,rustdesk и т.д.)")
    sys.exit(1)

# --- Подготовка структур ---
stats = defaultdict(lambda: defaultdict(lambda: {"count": 0, "first": None, "last": None}))
subdomain_hits = defaultdict(lambda: defaultdict(set))

ip_pattern = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
domain_pattern = re.compile(r'\((\d+)\)([a-zA-Z0-9\-]+)')
time_pattern = re.compile(r'(\d{1,2}[./]\d{1,2}[./]\d{4} \d{1,2}:\d{2}:\d{2})')

# --- Обработка параметра времени ---
def parse_time_filter(val):
    val = val.lower()
    try:
        num = int(val[:-1])
        unit = val[-1]
        if unit == "d":
            return timedelta(days=num)
        elif unit == "w":
            return timedelta(weeks=num)
        else:
            raise ValueError
    except Exception:
        print("❌ Неверный формат времени. Используй например: 1d, 3d, 1w")
        sys.exit(1)

time_limit = None
if time_filter:
    delta = parse_time_filter(time_filter)
    time_limit = datetime.now() - delta
    print(f"[INFO] Фильтрация по дате: последние {time_filter} (с {time_limit.strftime('%d.%m.%Y %H:%M:%S')})")

total = sum(1 for _ in open(file_path, encoding='utf-8', errors='ignore'))

def extract_l2_domain(full_domain):
    parts = full_domain.split('.')
    if len(parts) >= 2:
        return '.'.join(parts[-2:])
    return full_domain

def parse_timestamp(ts_str):
    """Парсит дату в datetime, поддерживает форматы 02.10.2025 и 02/10/2025"""
    for fmt in ("%d.%m.%Y %H:%M:%S", "%d/%m/%Y %H:%M:%S"):
        try:
            return datetime.strptime(ts_str, fmt)
        except ValueError:
            pass
    return None

# --- Основной парсинг ---
with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
    for i, line in enumerate(f, start=1):
        ip_match = ip_pattern.search(line)
        if not ip_match:
            continue
        ip = ip_match.group(0)

        raw_parts = domain_pattern.findall(line)
        if not raw_parts:
            continue
        domain_full = '.'.join(part[1] for part in raw_parts)

        timestamp_match = time_pattern.search(line)
        if not timestamp_match:
            continue
        timestamp_str = timestamp_match.group(1)
        timestamp_obj = parse_timestamp(timestamp_str)

        if time_limit and timestamp_obj and timestamp_obj < time_limit:
            continue

        if any(d in domain_full.lower() for d in domains):
            l2_domain = extract_l2_domain(domain_full)
            entry = stats[l2_domain][ip]
            entry["count"] += 1
            if entry["first"] is None:
                entry["first"] = timestamp_str
            entry["last"] = timestamp_str
            subdomain_hits[ip][l2_domain].add(domain_full)

        if debug and i % 200 == 0:
            print(f"[DEBUG] Обработка {i}/{total} строк ({(i/total)*100:.1f}%)")
            time.sleep(0.05)

# --- Вывод ---
if not stats:
    print("Совпадений не найдено.")
    sys.exit(0)

print("\n=== РЕЗУЛЬТАТ ===\n")

for domain, ip_data in stats.items():
    print(f"{domain}:")
    for ip, info in ip_data.items():
        print(f"  {ip} : {info['count']} : {info['first']} - {info['last']}")
    print()

print("=== IP с пересечениями по поддоменам ===\n")
has_overlap = False
for ip, doms in subdomain_hits.items():
    overlaps = {d: subs for d, subs in doms.items() if len(subs) > 1}
    if overlaps:
        has_overlap = True
        print(f"{ip}:")
        for d, subs in overlaps.items():
            print(f"  {d}: {', '.join(sorted(subs))}")
        print()
if not has_overlap:
    print("Пересечений не найдено.")
