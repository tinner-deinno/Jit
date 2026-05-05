#!/usr/bin/env python3
"""
karn Voice API — Speech-to-Text processing backend
Receives audio/transcript from web UI and saves to voices/ folder
"""

import os
import json
from datetime import datetime
from pathlib import Path
import argparse

# Configuration
VOICES_DIR = Path("/workspaces/Jit/voices")
VOICES_DIR.mkdir(exist_ok=True)

class KarnVoiceAPI:
    def __init__(self):
        self.voices_dir = VOICES_DIR

    def save_transcript(self, transcript: str, language: str = "th-TH", metadata: dict = None):
        """Save transcript as .md file"""
        timestamp = datetime.now().isoformat()
        filename = f"karn-{int(datetime.now().timestamp() * 1000)}.md"
        filepath = self.voices_dir / filename

        # Build markdown content
        word_count = len(transcript.split())
        md_content = f"""# 🎧 karn Voice Transcript

**Timestamp**: {timestamp}
**Language**: {language}
**Words**: {word_count}
**Status**: ✅ Recorded by karn

---

## Transcript

{transcript.strip()}

---

## Metadata

```json
{{
  "agent": "karn",
  "filename": "{filename}",
  "timestamp": "{timestamp}",
  "language": "{language}",
  "word_count": {word_count},
  "message_length": {len(transcript)}
}}
```
"""

        # Write file
        filepath.write_text(md_content, encoding='utf-8')

        return {
            "success": True,
            "filename": filename,
            "filepath": str(filepath),
            "timestamp": timestamp,
            "word_count": word_count,
            "status": "✅ Saved"
        }

    def list_transcripts(self, limit: int = 10):
        """List recent transcripts"""
        files = sorted(self.voices_dir.glob("karn-*.md"), reverse=True)[:limit]
        return [
            {
                "filename": f.name,
                "created": f.stat().st_mtime,
                "size_bytes": f.stat().st_size
            }
            for f in files
        ]

    def read_transcript(self, filename: str):
        """Read a transcript file"""
        filepath = self.voices_dir / filename
        if not filepath.exists():
            return {"error": "File not found"}

        return {
            "filename": filename,
            "content": filepath.read_text(encoding='utf-8')
        }

    def get_stats(self):
        """Get voice recording statistics"""
        files = list(self.voices_dir.glob("karn-*.md"))
        total_words = 0

        for f in files:
            content = f.read_text(encoding='utf-8')
            # Extract words from transcript section
            if "## Transcript" in content:
                transcript_section = content.split("## Transcript")[1].split("---")[0]
                total_words += len(transcript_section.split())

        return {
            "total_recordings": len(files),
            "total_words": total_words,
            "voices_dir": str(self.voices_dir),
            "avg_words_per_recording": total_words // len(files) if files else 0
        }

def cli():
    """Command-line interface"""
    parser = argparse.ArgumentParser(description="🎧 karn Voice API")
    subparsers = parser.add_subparsers(dest="command", help="Command")

    # Save command
    save_parser = subparsers.add_parser("save", help="Save transcript")
    save_parser.add_argument("--text", required=True, help="Transcript text")
    save_parser.add_argument("--lang", default="th-TH", help="Language code")

    # List command
    subparsers.add_parser("list", help="List recent transcripts")

    # Stats command
    subparsers.add_parser("stats", help="Show statistics")

    # Read command
    read_parser = subparsers.add_parser("read", help="Read transcript")
    read_parser.add_argument("filename", help="Filename to read")

    args = parser.parse_args()
    api = KarnVoiceAPI()

    if args.command == "save":
        result = api.save_transcript(args.text, args.lang)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.command == "list":
        transcripts = api.list_transcripts()
        print(f"\n📂 Recent Transcripts ({len(transcripts)}):\n")
        for t in transcripts:
            print(f"  • {t['filename']} ({t['size_bytes']} bytes)")
        print()

    elif args.command == "stats":
        stats = api.get_stats()
        print(f"\n📊 karn Voice Statistics:\n")
        for key, value in stats.items():
            print(f"  {key}: {value}")
        print()

    elif args.command == "read":
        result = api.read_transcript(args.filename)
        if "error" in result:
            print(f"❌ {result['error']}")
        else:
            print(f"\n📄 {result['filename']}:\n")
            print(result['content'])

    else:
        parser.print_help()

if __name__ == "__main__":
    cli()
