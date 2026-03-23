#!/bin/bash
# Install Killer UI into a project
# Usage: ./install.sh [target-project-directory]

set -e

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Killer UI to $TARGET..."

# Create directories
mkdir -p "$TARGET/.claude/skills/killer-ui/agents"
mkdir -p "$TARGET/.claude/skills/killer-ui/resources/knowledge-base"
mkdir -p "$TARGET/.claude/skills/killer-ui/templates"
mkdir -p "$TARGET/.claude/commands/KUI"

# Copy skill files
cp "$SCRIPT_DIR/SKILL.md" "$TARGET/.claude/skills/killer-ui/"
cp -R "$SCRIPT_DIR/agents/"*.md "$TARGET/.claude/skills/killer-ui/agents/" 2>/dev/null || true
cp -R "$SCRIPT_DIR/resources/" "$TARGET/.claude/skills/killer-ui/resources/" 2>/dev/null || true
cp -R "$SCRIPT_DIR/templates/"*.md "$TARGET/.claude/skills/killer-ui/templates/" 2>/dev/null || true

# Copy command files
cp "$SCRIPT_DIR/commands/"*.md "$TARGET/.claude/commands/KUI/"

echo ""
echo "Done! Killer UI is installed."
echo ""
echo "  Skill:    $TARGET/.claude/skills/killer-ui/"
echo "  Commands: $TARGET/.claude/commands/KUI/"
echo ""
echo "Commands:"
echo "  /KUI:review    — Critique your UI"
echo "  /KUI:system    — Create a design system"
echo "  /KUI:screen    — Design screens"
echo "  /KUI:brand     — Brand identity"
echo "  /KUI:a11y      — Accessibility audit"
echo "  /KUI:code      — Design to code"
echo "  /KUI:figma     — Figma specs"
echo "  /KUI:trends    — Trend research"
echo "  /KUI:darkmode  — Dark mode audit"
echo ""
echo "Start with /KUI:review to see what needs fixing."
