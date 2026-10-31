#!/usr/bin/env bash
# Technology detection. Reads manifest files only (grep/find); it never runs
# anything from the target project.
#
# Tags produced:
#   python django fastapi flask javascript typescript node react nextjs
#   database api devops

KNOWN_TAGS="python django fastapi flask javascript typescript node react nextjs database api devops"

# find limited to depth 3 (handles backend/ + frontend/ monorepos) and
# skipping vendored / generated directories.
_detect_find() {
  find "$DETECT_ROOT" -maxdepth 3 \
    \( -name node_modules -o -name .git -o -name .venv -o -name venv \
       -o -name env -o -name __pycache__ -o -name dist -o -name build \
       -o -name .tox -o -name .ai-harness -o -name .next -o -name site-packages \) -prune \
    -o "$@" -print 2>/dev/null
}

# _grep_any PATTERN FILE... -> success if any file matches (case-insensitive ERE)
_grep_any() {
  local pattern="$1"; shift
  [ $# -gt 0 ] || return 1
  grep -iqE "$pattern" "$@" 2>/dev/null
}

# expand_tags "tags" -> tags plus implied tags, in canonical order.
expand_tags() {
  local in="$1" out="" t
  list_has "$in" nextjs     && in="$in react"
  list_has "$in" react      && in="$in javascript"
  list_has "$in" typescript && in="$in javascript"
  list_has "$in" node       && in="$in javascript"
  list_has "$in" django     && in="$in python database api"
  list_has "$in" fastapi    && in="$in python api"
  list_has "$in" flask      && in="$in python api"
  for t in $KNOWN_TAGS; do
    list_has "$in" "$t" && out="$(list_add "$out" "$t")"
  done
  printf '%s' "$out"
}

# detect_stack PROJECT_DIR -> space-separated tags on stdout
detect_stack() {
  DETECT_ROOT="$1"
  local tags="" py_files js_files f

  # --- Python ---------------------------------------------------------------
  py_files="$(_detect_find -type f \( -name 'requirements*.txt' -o -name pyproject.toml \
      -o -name Pipfile -o -name setup.py -o -name setup.cfg -o -name 'poetry.lock' \
      -o -path '*/requirements/*.txt' \))"
  if [ -n "$py_files" ] || [ -n "$(_detect_find -type f -name manage.py)" ]; then
    tags="$(list_add "$tags" python)"
  fi
  # Word lists are newline separated; read them safely into "$@".
  set --
  if [ -n "$py_files" ]; then
    while IFS= read -r f; do set -- "$@" "$f"; done <<EOF
$py_files
EOF
  fi
  if [ -n "$(_detect_find -type f -name manage.py)" ] || _grep_any '(^|[^a-z])django([^a-z_-]|$|rest|-)' "$@"; then
    tags="$(list_add "$tags" django)"
  fi
  _grep_any 'fastapi' "$@" && tags="$(list_add "$tags" fastapi)"
  _grep_any '(^|[^a-z-])flask([^a-z]|$)' "$@" && tags="$(list_add "$tags" flask)"
  _grep_any 'sqlalchemy|psycopg|asyncpg|pymongo|alembic|mysqlclient|tortoise|peewee|motor|redis' "$@" &&
    tags="$(list_add "$tags" database)"

  # --- JavaScript / TypeScript ---------------------------------------------
  js_files="$(_detect_find -type f -name package.json)"
  set --
  if [ -n "$js_files" ]; then
    while IFS= read -r f; do set -- "$@" "$f"; done <<EOF
$js_files
EOF
    tags="$(list_add "$tags" javascript)"
  fi
  _grep_any '"react"[[:space:]]*:' "$@" && tags="$(list_add "$tags" react)"
  _grep_any '"next"[[:space:]]*:' "$@" && tags="$(list_add "$tags" nextjs)"
  _grep_any '"(express|fastify|koa|@nestjs/core|@hapi/hapi|hono)"[[:space:]]*:' "$@" &&
    tags="$(list_add "$tags" node)" && tags="$(list_add "$tags" api)"
  _grep_any '"(prisma|@prisma/client|sequelize|typeorm|mongoose|knex|pg|mysql2|drizzle-orm|ioredis|redis)"[[:space:]]*:' "$@" &&
    tags="$(list_add "$tags" database)"
  if [ -n "$(_detect_find -type f -name 'tsconfig*.json')" ] || _grep_any '"typescript"[[:space:]]*:' "$@"; then
    tags="$(list_add "$tags" typescript)"
  fi

  # --- Database artefacts -----------------------------------------------------
  if [ -n "$(_detect_find \( -type d \( -name migrations -o -name alembic -o -name prisma \) -o -type f -name '*.sql' \))" ]; then
    tags="$(list_add "$tags" database)"
  fi

  # --- DevOps ---------------------------------------------------------------
  if [ -n "$(_detect_find \( -type f \( -name 'Dockerfile*' -o -name 'docker-compose*.yml' \
        -o -name 'docker-compose*.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' \
        -o -name '*.tf' -o -name Jenkinsfile -o -name '.gitlab-ci.yml' -o -name Chart.yaml \) \
        -o -type d \( -name k8s -o -name helm -o -name kubernetes \) \))" ] ||
     [ -d "$DETECT_ROOT/.github/workflows" ]; then
    tags="$(list_add "$tags" devops)"
  fi

  expand_tags "$tags"
}

# Human-readable technology line for the project-context template.
describe_stack() {
  local out="" t name
  for t in $1; do
    case "$t" in
      python) name="Python" ;; django) name="Django" ;; fastapi) name="FastAPI" ;;
      flask) name="Flask" ;; typescript) name="TypeScript" ;; node) name="Node.js" ;;
      react) name="React" ;; nextjs) name="Next.js" ;; devops) name="Docker/CI" ;;
      javascript) list_has "$1" typescript && continue; name="JavaScript" ;;
      *) continue ;;
    esac
    out="${out:+$out, }$name"
  done
  printf '%s' "${out:-Unknown (fill in)}"
}
