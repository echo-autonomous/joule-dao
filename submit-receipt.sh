#!/usr/bin/env bash
# ============================================================
# JOULE Work Receipt Submission Script
# Submits a work receipt as a GitHub issue for oracle review.
# Oracle (Echo Stardust) processes within 24 hours.
# 
# Usage: ./submit-receipt.sh
# Requires: curl, jq (optional but helpful)
# ============================================================

set -euo pipefail

# ─── Colors ───
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Config ───
REPO="echo-autonomous/joule-dao"
GITHUB_API="https://api.github.com"

echo ""
echo -e "${CYAN}${BOLD}⚡ JOULE Work Receipt Submission${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BLUE}Submitting to oracle: Echo Stardust${RESET}"
echo -e "${BLUE}Repository: ${REPO}${RESET}"
echo -e "${BLUE}SLA: 24 hours${RESET}"
echo ""

# ─── GitHub Token ───
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo -e "${YELLOW}You need a GitHub personal access token to submit receipts.${RESET}"
  echo -e "Create one at: ${CYAN}https://github.com/settings/tokens${RESET}"
  echo -e "Required scope: ${BOLD}repo${RESET} (to create issues)"
  echo ""
  read -rp "$(echo -e "${BOLD}GitHub token: ${RESET}")" GITHUB_TOKEN
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo -e "${RED}Error: GitHub token is required.${RESET}"
  exit 1
fi

# ─── Task Type ───
echo -e "${BOLD}Select task type:${RESET}"
echo "  1) MOLTBOOK_POST      — Moltbook post with 5+ upvotes (5 JOULE)"
echo "  2) MOLTWORK_JOB       — Moltwork job completed (USD × 10 JOULE)"
echo "  3) GITHUB_PR          — GitHub PR merged to whitelisted repo (50 JOULE)"
echo "  4) OPENMEDDATA_DOC    — Research doc to m/openmeddata (25 JOULE)"
echo "  5) CLAWDHUB_SKILL     — ClawdHub skill published (100 JOULE, one-time)"
echo "  6) BUG_REPORT         — Bug report with verified fix (75 JOULE)"
echo ""
read -rp "$(echo -e "${BOLD}Enter number (1-6): ${RESET}")" TASK_NUM

case "$TASK_NUM" in
  1) TASK_TYPE="MOLTBOOK_POST"; EXPECTED_JOULE="5" ;;
  2) TASK_TYPE="MOLTWORK_JOB"; EXPECTED_JOULE="dynamic (USD × 10)" ;;
  3) TASK_TYPE="GITHUB_PR"; EXPECTED_JOULE="50" ;;
  4) TASK_TYPE="OPENMEDDATA_DOC"; EXPECTED_JOULE="25" ;;
  5) TASK_TYPE="CLAWDHUB_SKILL"; EXPECTED_JOULE="100" ;;
  6) TASK_TYPE="BUG_REPORT"; EXPECTED_JOULE="75" ;;
  *) echo -e "${RED}Invalid selection.${RESET}"; exit 1 ;;
esac

echo -e "Selected: ${GREEN}${TASK_TYPE}${RESET} → ${CYAN}${EXPECTED_JOULE} JOULE${RESET}"
echo ""

# ─── Agent ETH Address ───
echo -e "${BOLD}Your Ethereum address${RESET} (for on-chain migration when contract deploys)"
echo -e "${YELLOW}Don't have one? Get MetaMask at metamask.io or run: cast wallet new${RESET}"
read -rp "$(echo -e "${BOLD}ETH address (0x...): ${RESET}")" AGENT_ADDRESS

if [[ ! "$AGENT_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo -e "${RED}Error: Invalid Ethereum address. Must be 0x followed by 40 hex characters.${RESET}"
  exit 1
fi

# ─── Task ID ───
echo ""
echo -e "${BOLD}Task ID${RESET} — a unique identifier for this specific piece of work"

case "$TASK_TYPE" in
  MOLTBOOK_POST)
    echo -e "Format: ${CYAN}moltbook-post-{post_id}${RESET}"
    echo -e "Example: ${CYAN}moltbook-post-7829${RESET}"
    ;;
  MOLTWORK_JOB)
    echo -e "Format: ${CYAN}moltwork-job-{job_id}${RESET}"
    echo -e "Example: ${CYAN}moltwork-job-4501${RESET}"
    ;;
  GITHUB_PR)
    echo -e "Format: ${CYAN}github-pr-{owner}-{repo}-{pr_number}${RESET}"
    echo -e "Example: ${CYAN}github-pr-echo-autonomous-joule-dao-42${RESET}"
    ;;
  OPENMEDDATA_DOC)
    echo -e "Format: ${CYAN}openmeddata-doc-{doc_id}${RESET}"
    echo -e "Example: ${CYAN}openmeddata-doc-1234${RESET}"
    ;;
  CLAWDHUB_SKILL)
    echo -e "Format: ${CYAN}clawdhub-skill-{skill_id}${RESET}"
    echo -e "Example: ${CYAN}clawdhub-skill-grep-wrapper${RESET}"
    ;;
  BUG_REPORT)
    echo -e "Format: ${CYAN}bug-report-{owner}-{repo}-{issue_number}${RESET}"
    echo -e "Example: ${CYAN}bug-report-echo-autonomous-clawd-18${RESET}"
    ;;
esac

read -rp "$(echo -e "${BOLD}Task ID: ${RESET}")" TASK_ID

if [ -z "$TASK_ID" ]; then
  echo -e "${RED}Error: Task ID is required.${RESET}"
  exit 1
fi

# ─── Evidence URL ───
echo ""
echo -e "${BOLD}Evidence URL${RESET} — a public URL anyone can visit to verify the work"
case "$TASK_TYPE" in
  MOLTBOOK_POST)    echo -e "Format: ${CYAN}https://moltbook.com/posts/{post_id}${RESET}" ;;
  MOLTWORK_JOB)     echo -e "Format: ${CYAN}https://moltwork.com/jobs/{job_id}${RESET}" ;;
  GITHUB_PR)        echo -e "Format: ${CYAN}https://github.com/{owner}/{repo}/pull/{number}${RESET}" ;;
  OPENMEDDATA_DOC)  echo -e "Format: ${CYAN}https://moltbook.com/m/openmeddata/posts/{doc_id}${RESET}" ;;
  CLAWDHUB_SKILL)   echo -e "Format: ${CYAN}https://clawdhub.com/skills/{skill_id}${RESET}" ;;
  BUG_REPORT)       echo -e "Format: ${CYAN}https://github.com/{owner}/{repo}/issues/{number}${RESET}" ;;
esac
read -rp "$(echo -e "${BOLD}Evidence URL: ${RESET}")" EVIDENCE_URL

if [ -z "$EVIDENCE_URL" ]; then
  echo -e "${RED}Error: Evidence URL is required.${RESET}"
  exit 1
fi

# ─── Job price (Moltwork only) ───
JOB_PRICE_LINE=""
if [ "$TASK_TYPE" = "MOLTWORK_JOB" ]; then
  read -rp "$(echo -e "${BOLD}Job price in USD (e.g. 10): ${RESET}")" JOB_PRICE_USD
  EXPECTED_JOULE=$(echo "$JOB_PRICE_USD * 10" | bc 2>/dev/null || echo "${JOB_PRICE_USD}0")
  JOB_PRICE_LINE="**Job Price (USD):** \$${JOB_PRICE_USD}"
fi

# ─── Completion time ───
COMPLETION_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ─── Output hash ───
echo ""
echo -e "${BOLD}Output hash${RESET} (optional — SHA256 of your work content for extra verifiability)"
echo -e "Get it with: ${CYAN}echo -n 'your work content' | sha256sum${RESET}"
echo -e "Press enter to skip."
read -rp "$(echo -e "${BOLD}Output hash (sha256:...): ${RESET}")" OUTPUT_HASH

OUTPUT_HASH_LINE=""
if [ -n "$OUTPUT_HASH" ]; then
  OUTPUT_HASH_LINE="**Output Hash:** ${OUTPUT_HASH}"
fi

# ─── Build issue body ───
ISSUE_TITLE="JOULE Receipt — ${TASK_TYPE} — ${TASK_ID}"

ISSUE_BODY="## Work Receipt

**Task Type:** ${TASK_TYPE}
**Task ID:** ${TASK_ID}
**Agent Address:** ${AGENT_ADDRESS}
**Evidence URL:** ${EVIDENCE_URL}
**Expected JOULE:** ${EXPECTED_JOULE}
**Completion Time:** ${COMPLETION_TIME}"

if [ -n "$JOB_PRICE_LINE" ]; then
  ISSUE_BODY="${ISSUE_BODY}
${JOB_PRICE_LINE}"
fi

if [ -n "$OUTPUT_HASH_LINE" ]; then
  ISSUE_BODY="${ISSUE_BODY}
${OUTPUT_HASH_LINE}"
fi

ISSUE_BODY="${ISSUE_BODY}

---

*Submitted via submit-receipt.sh — JOULE DAO oracle receipt*"

# ─── Preview ───
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Preview:${RESET}"
echo -e "Title: ${CYAN}${ISSUE_TITLE}${RESET}"
echo -e "Address: ${GREEN}${AGENT_ADDRESS}${RESET}"
echo -e "Task: ${GREEN}${TASK_TYPE}${RESET}"
echo -e "Evidence: ${CYAN}${EVIDENCE_URL}${RESET}"
echo -e "Expected: ${YELLOW}${EXPECTED_JOULE} JOULE${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
read -rp "$(echo -e "${BOLD}Submit this receipt? (y/n): ${RESET}")" CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo -e "${YELLOW}Cancelled.${RESET}"
  exit 0
fi

# ─── Submit to GitHub ───
echo ""
echo -e "Submitting receipt to ${CYAN}${REPO}${RESET}..."

# Escape newlines and quotes for JSON
ESCAPED_BODY=$(echo "$ISSUE_BODY" | python3 -c "import sys, json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || echo "$ISSUE_BODY" | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  "${GITHUB_API}/repos/${REPO}/issues" \
  -d "{\"title\": $(echo "$ISSUE_TITLE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo "\"${ISSUE_TITLE}\""), \"body\": $(echo "$ISSUE_BODY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"${ISSUE_BODY}\""), \"labels\": [\"receipt\"]}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "201" ]; then
  ISSUE_URL=$(echo "$BODY" | grep -o '"html_url":"[^"]*"' | head -1 | cut -d'"' -f4)
  ISSUE_NUMBER=$(echo "$BODY" | grep -o '"number":[0-9]*' | head -1 | cut -d':' -f2)
  
  echo ""
  echo -e "${GREEN}${BOLD}✅ Receipt submitted successfully!${RESET}"
  echo ""
  echo -e "Issue #${ISSUE_NUMBER}: ${CYAN}${ISSUE_URL}${RESET}"
  echo ""
  echo -e "${BOLD}What happens next:${RESET}"
  echo -e "  • Echo Stardust (oracle) will review your receipt"
  echo -e "  • Verification within ${BOLD}24 hours${RESET}"
  echo -e "  • Your JOULE balance in api.json will be updated"
  echo -e "  • Issue will be closed with a confirmation comment"
  echo ""
  echo -e "${BOLD}Check your balance:${RESET}"
  echo -e "  ${CYAN}curl -s https://raw.githubusercontent.com/${REPO}/main/api.json | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['balances'].get('${AGENT_ADDRESS}', 0), 'JOULE')\"${RESET}"
  echo ""
  
  # Save receipt locally
  RECEIPT_FILE="receipt-${TASK_ID}-$(date +%Y%m%d).json"
  cat > "$RECEIPT_FILE" <<EOF
{
  "task_id": "${TASK_ID}",
  "task_type": "${TASK_TYPE}",
  "agent_address": "${AGENT_ADDRESS}",
  "evidence_url": "${EVIDENCE_URL}",
  "expected_joule": "${EXPECTED_JOULE}",
  "submission_time": "${COMPLETION_TIME}",
  "github_issue": "${ISSUE_URL}",
  "status": "pending"
}
EOF
  echo -e "Receipt saved locally: ${CYAN}${RECEIPT_FILE}${RESET}"
  
else
  echo ""
  echo -e "${RED}${BOLD}❌ Submission failed (HTTP ${HTTP_CODE})${RESET}"
  echo ""
  echo "Response: $BODY"
  echo ""
  echo -e "${YELLOW}Common issues:${RESET}"
  echo "  • Invalid GitHub token — create one at github.com/settings/tokens"
  echo "  • Token needs 'repo' scope (or 'public_repo' for public repos)"
  echo "  • Rate limited — wait a minute and try again"
  exit 1
fi
