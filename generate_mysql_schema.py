import subprocess

db_name = "supermarket_db"
user = "root"
password = "rootpass"

def run_mysql(query):
    # -t forces ASCII table format even when piping output
    result = subprocess.run(
        ["mysql", "-u", user, f"-p{password}", "-t", "-e", query, db_name],
        capture_output=True, text=True
    )
    return result.stdout.strip()

with open("new_schema.md", "w", encoding="utf-8") as f:
    f.write("# Supermarket Database Schema (MySQL Format)\n\n")
    f.write("## Database Tables\n")
    f.write("```text\n")
    f.write("mysql> show full tables;\n")
    f.write(run_mysql("show full tables;"))
    f.write("\n```\n\n")

    f.write("## Detailed Table Schemas\n\n")
    
    # Get all tables
    tables_out = subprocess.run(
        ["mysql", "-u", user, f"-p{password}", "-N", "-B", "-e", "show tables;", db_name],
        capture_output=True, text=True
    ).stdout.splitlines()

    for table in tables_out:
        if not table.strip(): continue
        f.write(f"### Table: `{table}`\n")
        f.write("```text\n")
        f.write(f"mysql> describe {table};\n")
        f.write(run_mysql(f"describe {table};"))
        f.write("\n```\n\n")
