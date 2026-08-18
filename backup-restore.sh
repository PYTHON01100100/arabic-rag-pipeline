#!/bin/bash
# Backup and restore script for Arabic RAG Pipeline
# Backs up ChromaDB and uploaded PDFs

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

echo "╔════════════════════════════════════════════════════════╗"
echo "║         Backup & Restore Tool                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Show menu
echo "Select operation:"
echo "1) Backup (save data)"
echo "2) Restore (restore from backup)"
echo "3) List backups"
echo "4) Restore latest backup"
echo ""
read -p "Select (1-4): " choice

case $choice in
    1)
        # BACKUP
        echo -e "${BLUE}Creating backup...${NC}"
        echo ""

        # Create backup directory
        mkdir -p "$BACKUP_DIR"

        # Stop running containers
        echo "Stopping containers..."
        docker compose down

        # Create backup
        echo "Backing up data..."
        tar -czf "$BACKUP_FILE" \
            streamlit_chroma_db/ \
            data/ \
            2>/dev/null || true

        size=$(du -h "$BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}✓ Backup created: $BACKUP_FILE ($size)${NC}"

        # Restart containers
        echo "Restarting containers..."
        docker compose up -d

        echo ""
        echo "Backup complete!"
        echo "Location: $BACKUP_FILE"
        ;;

    2)
        # RESTORE
        echo -e "${BLUE}Restoring from backup...${NC}"
        echo ""

        if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
            echo -e "${RED}No backups found!${NC}"
            exit 1
        fi

        echo "Available backups:"
        ls -1t "$BACKUP_DIR" | nl

        echo ""
        read -p "Select backup number: " backup_num

        backup_file=$(ls -1t "$BACKUP_DIR" | sed -n "${backup_num}p")

        if [ -z "$backup_file" ]; then
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi

        backup_path="$BACKUP_DIR/$backup_file"

        echo ""
        echo -e "${YELLOW}⚠ This will replace your current data${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi

        # Stop containers
        echo "Stopping containers..."
        docker compose down

        # Backup current data first
        if [ -d streamlit_chroma_db ]; then
            echo "Creating safety backup of current data..."
            tar -czf "$BACKUP_DIR/pre-restore_$TIMESTAMP.tar.gz" \
                streamlit_chroma_db/ \
                data/ \
                2>/dev/null || true
            echo "Safety backup created"
        fi

        # Remove current data
        echo "Removing current data..."
        rm -rf streamlit_chroma_db data

        # Extract backup
        echo "Restoring from backup..."
        tar -xzf "$backup_path"

        echo -e "${GREEN}✓ Restore complete${NC}"

        # Restart containers
        echo "Restarting containers..."
        docker compose up -d

        echo ""
        echo "Restore complete!"
        echo "Backup used: $backup_path"
        ;;

    3)
        # LIST BACKUPS
        if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
            echo "No backups found"
            exit 0
        fi

        echo -e "${BLUE}Available backups:${NC}"
        echo ""

        ls -lh "$BACKUP_DIR" | tail -n +2 | while read -r line; do
            filename=$(echo "$line" | awk '{print $NF}')
            size=$(echo "$line" | awk '{print $5}')
            date_str=$(echo "$line" | awk '{print $6, $7, $8}')
            echo "  $filename ($size) - $date_str"
        done

        total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
        echo ""
        echo "Total backup size: $total_size"
        ;;

    4)
        # RESTORE LATEST
        echo -e "${BLUE}Restoring latest backup...${NC}"
        echo ""

        latest_backup=$(ls -1t "$BACKUP_DIR" | head -n 1)

        if [ -z "$latest_backup" ]; then
            echo -e "${RED}No backups found${NC}"
            exit 1
        fi

        echo "Latest backup: $latest_backup"
        echo -e "${YELLOW}⚠ This will replace your current data${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            exit 0
        fi

        # Stop containers
        echo "Stopping containers..."
        docker compose down

        # Create safety backup
        if [ -d streamlit_chroma_db ]; then
            echo "Creating safety backup..."
            tar -czf "$BACKUP_DIR/pre-restore_$TIMESTAMP.tar.gz" \
                streamlit_chroma_db/ \
                data/ \
                2>/dev/null || true
        fi

        # Remove current data
        echo "Removing current data..."
        rm -rf streamlit_chroma_db data

        # Extract latest backup
        echo "Restoring from $latest_backup..."
        tar -xzf "$BACKUP_DIR/$latest_backup"

        echo -e "${GREEN}✓ Restore complete${NC}"

        # Restart
        echo "Restarting containers..."
        docker compose up -d

        echo ""
        echo "Latest backup restored!"
        echo "Your previous data is saved as: pre-restore_$TIMESTAMP.tar.gz"
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "For more information, see:"
echo "  LLM_DEPLOYMENT.md § Backup & Recovery"
echo ""
