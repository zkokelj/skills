# Cebelca.biz / InvoiceFox API config for the `invoice` skill.
# Copy to config.sh and fill in your values:  cp config.example.sh config.sh
#
# The API token itself goes in a separate file next to this one:
#   echo 'YOUR_API_TOKEN' > ~/.claude/skills/invoice/.token
# (Get it in the webapp: Nastavitve > Nastavitve dostopa, bottom of the page.)

# Production endpoint chosen for this skill.
BASE_URL="https://www.cebelca.biz"

# --- Fiscalization defaults (only used by `issue-cash`) ----------------------
# These get sent to the tax office (FURS), so they must be correct/real.
OP_TAX_ID="12345678"      # personal tax id of the person issuing the invoice
OP_NAME="PRODAJALEC1"     # operator name/handle printed on the invoice
ID_LOCATION="7"           # id of a registered sales location (run `locations`)

# 1 = fiscalize against the TEST FURS server, 0 = real FURS.
# Keep this at 1 until you have verified a full run end-to-end.
TEST_MODE="1"
