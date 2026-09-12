#!/usr/bin/env bash

set -Eeuo pipefail

CI_INVENTORY=".github/ci/inventory.yml"

echo "===== Tool versions ====="
python --version
ansible --version
yamllint --version

echo "===== YAML lint ====="
yamllint \
  -c .yamllint \
  inventory \
  playbooks \
  roles \
  "${CI_INVENTORY}" \
  .github/workflows/ansible-quality.yml

echo "===== CI Inventory graph ====="
ansible-inventory \
  -i "${CI_INVENTORY}" \
  --graph

echo "===== Playbook syntax checks ====="

PLAYBOOK_COUNT=0
PLAYBOOK_FAILURES=0

while IFS= read -r playbook; do
  PLAYBOOK_COUNT=$((PLAYBOOK_COUNT + 1))

  echo
  echo "Checking ${playbook}"

  if ! ansible-playbook \
    -i "${CI_INVENTORY}" \
    "${playbook}" \
    --syntax-check; then
    PLAYBOOK_FAILURES=$((PLAYBOOK_FAILURES + 1))
  fi
done < <(
  find playbooks \
    -maxdepth 1 \
    -type f \
    -name '*.yml' \
    ! -name '*.bak*' \
    -print |
  sort
)

echo
echo "Playbooks checked: ${PLAYBOOK_COUNT}"
echo "Playbook failures: ${PLAYBOOK_FAILURES}"

if [ "${PLAYBOOK_FAILURES}" -ne 0 ]; then
  echo "PLAYBOOK_SYNTAX_VALIDATION_FAILED"
  exit 1
fi

echo "===== Tracked sensitive filename check ====="

SENSITIVE_FILENAME_PATTERN='(^|/)(id_rsa|id_ed25519|.*vault.*pass.*|.*password-file.*|.*\.p12|.*\.pfx)$'

if git ls-files |
   grep -Ei "${SENSITIVE_FILENAME_PATTERN}"; then
  echo "TRACKED_SENSITIVE_FILENAME_FOUND"
  exit 1
else
  echo "TRACKED_SENSITIVE_FILENAME_CHECK_PASS"
fi

echo "===== Private key content check ====="

if git grep \
  -IlE \
  'BEGIN (OPENSSH|RSA|EC|DSA)? ?PRIVATE KEY' \
  -- .; then
  echo "TRACKED_PRIVATE_KEY_FOUND"
  exit 1
else
  echo "TRACKED_PRIVATE_KEY_CHECK_PASS"
fi

echo "===== Commit whitespace check ====="

git show \
  --check \
  --format= \
  HEAD

echo "===== Final result ====="
echo "ANSIBLE_STATIC_VALIDATION_PASS"
