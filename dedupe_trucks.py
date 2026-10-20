import re
import sys

with open('supabase/migrations/0028_lafarge_data_import.sql', 'r') as f:
    content = f.read()

lines = content.splitlines()
start_idx = None
for i, line in enumerate(lines):
    if line.strip().startswith('insert into public.trucks'):
        start_idx = i
        break
if start_idx is None:
    print("Could not find trucks insert")
    sys.exit(1)
values_start = None
for i in range(start_idx, len(lines)):
    if lines[i].strip().startswith('from (values'):
        values_start = i
        break
if values_start is None:
    print("Could not find values start")
    sys.exit(1)
values_end = None
for i in range(values_start, len(lines)):
    if ') as t(' in lines[i]:
        values_end = i
        break
if values_end is None:
    print("Could not find values end")
    sys.exit(1)
value_lines = lines[values_start+1:values_end]
seen = set()
unique_lines = []
for line in value_lines:
    parts = line.split(',')
    if len(parts) < 1:
        continue
    first = parts[0].strip()
    if first.startswith('('):
        first = first[1:]
    if first.startswith("'"):
        reg_no = first.split("'")[1] if "'" in first else first
    else:
        reg_no = first.strip()
    if reg_no in seen:
        continue
    seen.add(reg_no)
    unique_lines.append(line)
new_lines = lines[:values_start+1] + unique_lines + lines[values_end:]
new_content = '\n'.join(new_lines)
with open('supabase/migrations/0028_lafarge_data_import.sql', 'w') as f:
    f.write(new_content)
print(f"Deduplicated: removed {len(value_lines) - len(unique_lines)} duplicate lines")
