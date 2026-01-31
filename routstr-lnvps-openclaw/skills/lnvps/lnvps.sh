#!/bin/bash

set -e

# LNVPS Management Script
# Check VM expiry dates and get renewal invoices
# Requires: nak, jq, curl

API_BASE="https://api.lnvps.net/api/v1"
CONFIG_FILE="$HOME/.openclaw/identity/nostr.config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check dependencies
command -v nak >/dev/null 2>&1 || { echo -e "${RED}Error: nak (nostr army knife) is required. Install from https://github.com/fiatjaf/nak${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${RED}Error: jq is required${NC}"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo -e "${RED}Error: curl is required${NC}"; exit 1; }

# Read Nostr keys from config
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Nostr config not found at $CONFIG_FILE${NC}"
    exit 1
fi

NSEC=$(jq -r '.private_key.nsec' "$CONFIG_FILE")
HEX_KEY=$(jq -r '.private_key.hex' "$CONFIG_FILE")
NPUB=$(jq -r '.public_key.npub' "$CONFIG_FILE")

if [ -z "$NSEC" ] || [ "$NSEC" = "null" ]; then
    echo -e "${RED}Error: Could not read private key from config${NC}"
    exit 1
fi

# Function to create NIP-98 auth event
nip98_auth() {
    local method="$1"
    local url="$2"
    local payload="${3:-}"
    
    local signed_event
    
    if [ -n "$payload" ]; then
        local payload_hash=$(echo -n "$payload" | sha256sum | cut -d' ' -f1)
        signed_event=$(nak event -k 27235 -c "" \
            -t "u=$url" \
            -t "method=$method" \
            -t "payload=$payload_hash" \
            --sec "$NSEC" 2>/dev/null)
    else
        signed_event=$(nak event -k 27235 -c "" \
            -t "u=$url" \
            -t "method=$method" \
            --sec "$NSEC" 2>/dev/null)
    fi
    
    echo "$signed_event" | base64 -w 0
}

# Function to make authenticated API call
api_call() {
    local method="$1"
    local endpoint="$2"
    local payload="${3:-}"
    local url="${API_BASE}${endpoint}"
    
    local auth_token=$(nip98_auth "$method" "$url" "$payload")
    
    if [ -n "$payload" ]; then
        curl -s -X "$method" \
            -H "Authorization: Nostr $auth_token" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$url"
    else
        curl -s -X "$method" \
            -H "Authorization: Nostr $auth_token" \
            "$url"
    fi
}

# Function to format timestamp
format_date() {
    local timestamp="$1"
    if [ -n "$timestamp" ] && [ "$timestamp" != "null" ]; then
        date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$timestamp"
    else
        echo "N/A"
    fi
}

# Function to calculate days until expiry
days_until() {
    local date_str="$1"
    if [ -n "$date_str" ] && [ "$date_str" != "null" ]; then
        local expiry_ts=$(date -d "$date_str" +%s 2>/dev/null)
        if [ -n "$expiry_ts" ]; then
            local now=$(date +%s)
            local diff=$(( (expiry_ts - now) / 86400 ))
            echo "$diff"
        else
            echo "?"
        fi
    else
        echo "?"
    fi
}

# Command: list - Simple list of VMs
cmd_list() {
    echo -e "${BLUE}Fetching VMs...${NC}"
    
    local response=$(api_call "GET" "/vm")
    local vms=$(echo "$response" | jq -r '.data // []')
    
    if [ -z "$vms" ] || [ "$vms" = "[]" ] || [ "$vms" = "null" ]; then
        echo -e "${YELLOW}No VMs found${NC}"
        return
    fi
    
    echo ""
    echo "ID    | Status  | IP"
    echo "------|---------|------------------"
    echo "$vms" | jq -r '.[] | "\(.id)    | \(.status // "unknown") | \(.ip_assignments[0].ip // "pending")"'
}

# Command: status - Detailed status with expiry dates
cmd_status() {
    echo -e "${BLUE}=== LNVPS VM Status ===${NC}"
    echo -e "Account: ${GREEN}$NPUB${NC}"
    echo ""
    
    local response=$(api_call "GET" "/vm")
    local vms=$(echo "$response" | jq -r '.data // []')
    
    if [ -z "$vms" ] || [ "$vms" = "[]" ] || [ "$vms" = "null" ]; then
        echo -e "${YELLOW}No VMs found for this account${NC}"
        return
    fi
    
    local vm_count=$(echo "$vms" | jq 'length')
    echo -e "Found ${GREEN}$vm_count${NC} VM(s):"
    echo ""
    
    echo "$vms" | jq -c '.[]' | while read -r vm; do
        local id=$(echo "$vm" | jq -r '.id')
        local status_obj=$(echo "$vm" | jq -r '.status // {}')
        local state=$(echo "$status_obj" | jq -r '.state // "unknown"' 2>/dev/null || echo "unknown")
        local expires=$(echo "$vm" | jq -r '.expires // null')
        local ip=$(echo "$vm" | jq -r '.ip_assignments[0].ip // "pending"')
        local template=$(echo "$vm" | jq -r '.template.name // "unknown"')
        local image=$(echo "$vm" | jq -r '.image.distribution // "unknown"')
        
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "VM ID:      ${GREEN}$id${NC}"
        echo -e "Template:   $template"
        echo -e "OS:         $image"
        echo -e "IP:         $ip"
        
        # Status with color (state comes from status.state in the API)
        case "$state" in
            "running")
                echo -e "Status:     ${GREEN}$state${NC}"
                ;;
            "stopped"|"expired")
                echo -e "Status:     ${RED}$state${NC}"
                ;;
            *)
                echo -e "Status:     ${YELLOW}$state${NC}"
                ;;
        esac
        
        # Expiry with warning colors
        if [ -n "$expires" ] && [ "$expires" != "null" ]; then
            local expiry_date=$(format_date "$expires")
            local days_left=$(days_until "$expires")
            
            if [ "$days_left" -lt 0 ]; then
                echo -e "Expires:    ${RED}$expiry_date (EXPIRED)${NC}"
            elif [ "$days_left" -lt 3 ]; then
                echo -e "Expires:    ${RED}$expiry_date ($days_left days left)${NC}"
            elif [ "$days_left" -lt 7 ]; then
                echo -e "Expires:    ${YELLOW}$expiry_date ($days_left days left)${NC}"
            else
                echo -e "Expires:    ${GREEN}$expiry_date ($days_left days left)${NC}"
            fi
        else
            echo -e "Expires:    ${YELLOW}N/A${NC}"
        fi
        echo ""
    done
}

# Command: renew - Get renewal invoice for a VM
cmd_renew() {
    local vm_id="$1"
    
    if [ -z "$vm_id" ]; then
        echo -e "${RED}Error: VM ID required${NC}"
        echo "Usage: $0 renew <vm_id>"
        echo ""
        echo "Run '$0 list' to see your VM IDs"
        exit 1
    fi
    
    echo -e "${BLUE}=== Get Renewal Invoice ===${NC}"
    echo -e "VM ID: ${GREEN}$vm_id${NC}"
    echo ""
    
    # First get VM details to show what we're renewing
    echo "Fetching VM details..."
    local vm_response=$(api_call "GET" "/vm/${vm_id}")
    local vm_data=$(echo "$vm_response" | jq -r '.data // null')
    
    if [ -z "$vm_data" ] || [ "$vm_data" = "null" ]; then
        echo -e "${RED}Error: Could not fetch VM details${NC}"
        echo "Response: $vm_response"
        exit 1
    fi
    
    local template=$(echo "$vm_data" | jq -r '.template.name // "unknown"')
    local current_expiry=$(echo "$vm_data" | jq -r '.expires // null')
    
    echo -e "Template: $template"
    if [ -n "$current_expiry" ] && [ "$current_expiry" != "null" ]; then
        echo -e "Current expiry: $(format_date "$current_expiry")"
    fi
    echo ""
    
    # Get renewal invoice
    echo "Requesting renewal invoice..."
    local payment_response=$(api_call "GET" "/vm/${vm_id}/renew")
    local payment=$(echo "$payment_response" | jq -r '.data // null')
    
    if [ -z "$payment" ] || [ "$payment" = "null" ]; then
        echo -e "${RED}Error: Could not get renewal invoice${NC}"
        echo "Response: $payment_response"
        exit 1
    fi
    
    local payment_id=$(echo "$payment" | jq -r '.id')
    local invoice=$(echo "$payment" | jq -r '.data.lightning // .invoice // null')
    local amount_raw=$(echo "$payment" | jq -r '.amount // 0')
    local amount=$((amount_raw / 1000))
    local currency=$(echo "$payment" | jq -r '.currency // "BTC"')
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}RENEWAL INVOICE${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "Payment ID: ${BLUE}$payment_id${NC}"
    echo -e "Amount:     ${YELLOW}$amount sats${NC}"
    echo ""
    echo -e "${BLUE}Lightning Invoice:${NC}"
    echo "$invoice"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Output just the invoice for easy copying
    echo ""
    echo "Copy the invoice above and pay with any Lightning wallet."
}

# Command: help
cmd_help() {
    echo "LNVPS Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status          Show all VMs with expiry dates"
    echo "  list            Simple list of VM IDs"
    echo "  renew <vm_id>   Get Lightning invoice to renew a VM"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 renew 884"
}

# Main
case "${1:-help}" in
    status)
        cmd_status
        ;;
    list)
        cmd_list
        ;;
    renew)
        cmd_renew "$2"
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        cmd_help
        exit 1
        ;;
esac
