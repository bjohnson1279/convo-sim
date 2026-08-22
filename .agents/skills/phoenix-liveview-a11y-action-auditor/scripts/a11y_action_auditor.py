#!/usr/bin/env python3
"""
Phoenix LiveView Accessibility & Action Feedback Auditor CLI
Audits HEEx templates and LiveView modules for loading feedback (phx-disable-with),
icon accessibility (aria-label/title), destructive confirmation guards (data-confirm),
and dynamic live regions (aria-live).
"""

import argparse
import json
import os
import re
import sys

# Force UTF-8 encoding across Windows console streams
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')


def log(msg, **kwargs):
    print(msg, flush=True, **kwargs)


def find_heex_files(target_path):
    files = []
    if os.path.isfile(target_path):
        return [target_path]
    
    for root, _, filenames in os.walk(target_path):
        for f in filenames:
            if f.endswith(('.heex', '.ex')):
                files.append(os.path.join(root, f))
    return files


def extract_template_blocks(filepath):
    """
    Extracts template content and line offsets from .heex files or ~H inline blocks in .ex files.
    """
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()

    blocks = []
    if filepath.endswith('.heex'):
        blocks.append((content, 1))
    else:
        # Match ~H"""...""" or ~H"..."
        pattern = re.compile(r'~H("""(.*?)"""|"(.*?)")', re.DOTALL)
        for match in pattern.finditer(content):
            start_pos = match.start()
            line_offset = content.count('\n', 0, start_pos) + 1
            matched_text = match.group(2) if match.group(2) is not None else match.group(3)
            blocks.append((matched_text, line_offset))
    return blocks, content


def parse_attributes(tag_content):
    attrs = {}
    i = 0
    n = len(tag_content)
    while i < n:
        while i < n and tag_content[i].isspace():
            i += 1
        if i >= n:
            break
        
        start_name = i
        while i < n and (tag_content[i].isalnum() or tag_content[i] in '_-:@.'):
            i += 1
        key = tag_content[start_name:i]
        if not key:
            i += 1
            continue
            
        while i < n and tag_content[i].isspace():
            i += 1
        if i < n and tag_content[i] == '=':
            i += 1
            while i < n and tag_content[i].isspace():
                i += 1
            if i >= n:
                attrs[key] = ""
                break
            
            if tag_content[i] in ['"', "'"]:
                quote = tag_content[i]
                i += 1
                start_val = i
                while i < n and tag_content[i] != quote:
                    if tag_content[i] == '\\':
                        i += 1
                    i += 1
                val = tag_content[start_val:i]
                if i < n:
                    i += 1
                attrs[key] = val
            elif tag_content[i] == '{':
                i += 1
                start_val = i
                brace_depth = 1
                in_str = None
                while i < n and brace_depth > 0:
                    ch = tag_content[i]
                    if in_str:
                        if ch == in_str:
                            in_str = None
                        elif ch == '\\':
                            i += 1
                    else:
                        if ch in ['"', "'"]:
                            in_str = ch
                        elif ch == '{':
                            brace_depth += 1
                        elif ch == '}':
                            brace_depth -= 1
                    i += 1
                end_val = i - 1 if brace_depth == 0 else i
                val = tag_content[start_val:end_val].strip()
                if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                    val = val[1:-1]
                attrs[key] = val
            else:
                start_val = i
                while i < n and not tag_content[i].isspace() and tag_content[i] not in '>/':
                    i += 1
                attrs[key] = tag_content[start_val:i]
        else:
            attrs[key] = ""
    return attrs


def generate_suggested_disable_with(action_name, button_text):
    # Strip HTML tags like <.icon .../> from button text first
    clean_text = re.sub(r'<[^>]+>', '', button_text or '')
    clean_text = re.sub(r'\{[^\}]+\}', '', clean_text).strip()
    text = (clean_text or action_name or "").lower().strip()
    words = re.findall(r'[a-z]+', text)
    if not words:
        return "Processing..."
    
    verb = words[0]
    mapping = {
        "send": "Sending...",
        "stop": "Stopping...",
        "spawn": "Spawning...",
        "create": "Creating...",
        "save": "Saving...",
        "delete": "Deleting...",
        "remove": "Removing...",
        "cancel": "Canceling...",
        "submit": "Submitting...",
        "start": "Starting...",
        "load": "Loading...",
        "update": "Updating...",
        "refresh": "Refreshing...",
        "search": "Searching...",
        "filter": "Filtering..."
    }
    if verb in mapping:
        return mapping[verb]
    if verb.endswith('e'):
        return verb[:-1].capitalize() + "ing..."
    return verb.capitalize() + "ing..."


def audit_template(filepath, block_text, base_line_offset):
    issues = []
    
    # Match button, .button, a, .link, and form tags
    tag_regex = re.compile(r'(<(button|\.button|a|\.link|form|\.form)\b([^>]*?)>(.*?)</\2>|<(button|\.button|input)\b([^>]*?)/?>)', re.DOTALL | re.IGNORECASE)
    
    for match in tag_regex.finditer(block_text):
        tag_start_pos = match.start()
        line_num = base_line_offset + block_text.count('\n', 0, tag_start_pos)
        
        full_tag = match.group(0)
        tag_name = match.group(2) or match.group(5)
        raw_attrs = match.group(3) or match.group(6) or ""
        inner_content = match.group(4) if match.group(4) is not None else ""
        
        attrs = parse_attributes(raw_attrs)
        dom_id = attrs.get('id', '')
        phx_click = attrs.get('phx-click', '')
        phx_submit = attrs.get('phx-submit', '')
        phx_disable_with = attrs.get('phx-disable-with', '')
        aria_label = attrs.get('aria-label', '')
        aria_labelledby = attrs.get('aria-labelledby', '')
        title = attrs.get('title', '')
        data_confirm = attrs.get('data-confirm', '')
        
        # 1. Missing Loading Feedback (Exclude client-only JS commands like JS.dispatch/JS.toggle)
        action = phx_click or phx_submit
        is_client_only_js = bool(re.search(r'JS\.(dispatch|toggle|show|hide|add_class|remove_class|set_attribute)', action)) and "JS.push" not in action
        
        if (phx_click or phx_submit) and not is_client_only_js and not phx_disable_with:
            suggested = generate_suggested_disable_with(action, inner_content)
            issues.append({
                "file": filepath,
                "line": line_num,
                "type": "MISSING_PHX_DISABLE_WITH",
                "severity": "WARNING",
                "element": f"<{tag_name} id='{dom_id}'>",
                "id": dom_id,
                "message": f"Action element with {phx_click and 'phx-click' or 'phx-submit'}='{action}' lacks phx-disable-with feedback.",
                "suggested_fix": f'phx-disable-with="{suggested}"'
            })
            
        # 2. Icon-Only Action Missing Accessible Label
        has_icon = bool(re.search(r'(<\.icon\b|<svg\b)', inner_content, re.IGNORECASE))
        # Strip html tags and template interpolations from inner text
        clean_text = re.sub(r'<[^>]+>', '', inner_content)
        clean_text = re.sub(r'\{[^\}]+\}', '', clean_text).strip()
        
        if has_icon and not clean_text and not aria_label and not aria_labelledby and not title:
            issues.append({
                "file": filepath,
                "line": line_num,
                "type": "MISSING_A11Y_LABEL",
                "severity": "ERROR",
                "element": f"<{tag_name} id='{dom_id}'>",
                "id": dom_id,
                "message": "Icon-only interactive element lacks aria-label, aria-labelledby, or title.",
                "suggested_fix": f'aria-label="{dom_id and dom_id.replace("-", " ").title() or "Action"}"'
            })
            
        # 3. Destructive Action Missing Confirmation Guard
        text_and_action = f"{phx_click} {dom_id} {inner_content}".lower()
        destructive_keywords = ["delete", "remove", "destroy", "kill", "terminate", "stop_conversation"]
        if any(kw in text_and_action for kw in destructive_keywords) and not data_confirm:
            issues.append({
                "file": filepath,
                "line": line_num,
                "type": "MISSING_DESTRUCTIVE_CONFIRM",
                "severity": "WARNING",
                "element": f"<{tag_name} id='{dom_id}'>",
                "id": dom_id,
                "message": "Destructive action lacks data-confirm safety prompt.",
                "suggested_fix": 'data-confirm="Are you sure you want to perform this action?"'
            })

    # 4. Live Region Dynamic Status Check
    status_regex = re.compile(r'<div\b([^>]*?class="[^"]*?(?:status|badge|pill|alert)[^"]*?"[^>]*?)>', re.IGNORECASE)
    for match in status_regex.finditer(block_text):
        tag_start_pos = match.start()
        line_num = base_line_offset + block_text.count('\n', 0, tag_start_pos)
        raw_attrs = match.group(1)
        attrs = parse_attributes(raw_attrs)
        aria_live = attrs.get('aria-live', '')
        role = attrs.get('role', '')
        
        if not aria_live and role not in ['status', 'alert', 'log']:
            # Only flag if it appears to wrap dynamic template expressions
            surrounding = block_text[tag_start_pos:tag_start_pos + 200]
            if '{' in surrounding or '<%=' in surrounding:
                issues.append({
                    "file": filepath,
                    "line": line_num,
                    "type": "RECOMMEND_ARIA_LIVE",
                    "severity": "INFO",
                    "element": "<div status/badge container>",
                    "id": attrs.get('id', ''),
                    "message": "Dynamic status container could benefit from aria-live='polite' for screen-reader announcement.",
                    "suggested_fix": 'aria-live="polite" aria-atomic="true"'
                })

    return issues


def cmd_scan(args):
    files = find_heex_files(args.path)
    all_issues = []
    
    log(f"🔍 Scanning {len(files)} file(s) for LiveView accessibility & action feedback...")
    for f in files:
        blocks, _ = extract_template_blocks(f)
        for block_text, line_offset in blocks:
            issues = audit_template(f, block_text, line_offset)
            all_issues.extend(issues)
            
    summary = {
        "total_files": len(files),
        "total_issues": len(all_issues),
        "errors": len([i for i in all_issues if i['severity'] == 'ERROR']),
        "warnings": len([i for i in all_issues if i['severity'] == 'WARNING']),
        "info": len([i for i in all_issues if i['severity'] == 'INFO']),
        "issues": all_issues
    }
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as out_f:
            json.dump(summary, out_f, indent=2)
        log(f"💾 Audit report written to: {args.output}")
        
    log("\n" + "=" * 80)
    log(f"📊 Audit Summary: {summary['total_issues']} findings ({summary['errors']} errors, {summary['warnings']} warnings, {summary['info']} info)")
    log("=" * 80)
    
    if not all_issues:
        log("✨ All LiveView interactive elements comply with accessibility and action feedback standards!")
    else:
        for i in all_issues:
            rel_file = os.path.relpath(i['file']) if os.path.isabs(i['file']) else i['file']
            log(f"[{i['severity']}] {rel_file}:{i['line']} -> {i['message']}")
            log(f"    Element: {i['element']}")
            log(f"    Suggested: {i['suggested_fix']}\n")
            
    return 0 if summary['errors'] == 0 else 1


def cmd_generate_tests(args):
    files = find_heex_files(args.path)
    test_assertions = []
    
    for filepath in files:
        blocks, _ = extract_template_blocks(filepath)
        for block_text, _ in blocks:
            tag_regex = re.compile(r'<(button|\.button|a|\.link)\b([^>]*?)>', re.DOTALL | re.IGNORECASE)
            for match in tag_regex.finditer(block_text):
                raw_attrs = match.group(2)
                attrs = parse_attributes(raw_attrs)
                dom_id = attrs.get('id', '')
                phx_disable_with = attrs.get('phx-disable-with', '')
                aria_label = attrs.get('aria-label', '')
                data_confirm = attrs.get('data-confirm', '')
                
                if dom_id:
                    if phx_disable_with:
                        test_assertions.append(f'assert has_element?(view, ~s|button#{dom_id}[phx-disable-with="{phx_disable_with}"]|)')
                    if aria_label:
                        test_assertions.append(f'assert has_element?(view, ~s|button#{dom_id}[aria-label="{aria_label}"]|)')
                    if data_confirm:
                        test_assertions.append(f'assert has_element?(view, ~s|button#{dom_id}[data-confirm="{data_confirm}"]|)')

    output_lines = [
        "# Auto-generated LiveView Accessibility Assertions",
        "# Add these assertions into your LiveView test suite:\n"
    ] + test_assertions
    
    output_text = "\n".join(output_lines)
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_text + "\n")
        log(f"💾 Generated {len(test_assertions)} test assertion(s) to: {args.output}")
    else:
        log(output_text)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Phoenix LiveView Accessibility & Action Feedback Auditor CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Scan
    scan_p = subparsers.add_parser("scan", help="Scan HEEx templates for accessibility and feedback gaps")
    scan_p.add_argument("--path", default="lib", help="Target path to scan (defaults to lib)")
    scan_p.add_argument("--output", help="Optional path to output JSON summary")
    
    # Generate Tests
    test_p = subparsers.add_parser("generate-tests", help="Generate LiveViewTest assertions for UI actions")
    test_p.add_argument("--path", default="lib", help="Target path to scan")
    test_p.add_argument("--output", help="Optional file to save generated Elixir test assertions")
    
    args = parser.parse_args()
    if args.command == "scan":
        sys.exit(cmd_scan(args))
    elif args.command == "generate-tests":
        sys.exit(cmd_generate_tests(args))


if __name__ == "__main__":
    main()
