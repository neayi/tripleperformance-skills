#!/usr/bin/env python3
"""Récupère avec yt-dlp ce qu'il faut pour créer une page Vidéo Triple Performance.

Écrit dans le dossier de sortie (par défaut tp-travail/youtube-<id>/) :
- info.json                     métadonnées complètes renvoyées par yt-dlp ;
- video.json                    champs utiles au modèle Vidéo (titre nettoyé, date, durée…) ;
- description.txt               description de la vidéo ;
- transcription.txt             transcription brute (texte seul, sans horodatage) ;
- transcription-chapitres.txt   la même, découpée selon les chapitres de la vidéo (s'il y en a) ;
- thumbnail_youtube_<id>.jpg    vignette convertie en JPEG.

Vérifie d'abord, par Semantic MediaWiki, que la vidéo n'est pas déjà sur le wiki ;
si c'est le cas, affiche les pages concernées et s'arrête (code 3) sauf avec --force.

Usage : youtube.py <url-ou-id> [--lang fr] [--out DOSSIER] [--wiki URL] [--force]
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ID_RE = re.compile(r"(?:v=|youtu\.be/|shorts/|live/|embed/)([A-Za-z0-9_-]{11})")
# Caractères interdits dans un titre MediaWiki ; « _ » équivaut à une espace
FORBIDDEN_RE = re.compile(r"[#<>\[\]|{}_]")
TAG_RE = re.compile(r"<[^>]+>")
TIMING_RE = re.compile(r"^(\d{2}):(\d{2}):(\d{2})\.\d{3} --> ")


def video_id(arg):
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", arg):
        return arg
    match = ID_RE.search(arg)
    if not match:
        sys.exit(f"Identifiant de vidéo introuvable dans : {arg}")
    return match.group(1)


def existing_pages(wiki, vid):
    """Pages du wiki dont la propriété « A une URL de vidéo » contient l'identifiant."""
    query = f"[[A une URL de vidéo::~*{vid}*]]|?A une URL de vidéo"
    url = f"{wiki.rstrip('/')}/api.php?" + urllib.parse.urlencode({"action": "ask", "format": "json", "query": query})
    request = urllib.request.Request(url, headers={"User-Agent": "tripleperformance-skills/youtube.py"})
    with urllib.request.urlopen(request, timeout=30) as response:
        results = json.load(response).get("query", {}).get("results") or {}
    return [{"titre": title, "url": "https:" + page["fullurl"] if page["fullurl"].startswith("//") else page["fullurl"]}
            for title, page in results.items()]


def run_ytdlp(args):
    if not shutil.which("yt-dlp"):
        sys.exit("yt-dlp est introuvable : relancez le script d'installation du dépôt des skills.")
    result = subprocess.run(["yt-dlp", "--no-warnings", *args], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        sys.exit(f"Échec de yt-dlp :\n{result.stderr.strip()}")
    return result.stdout


def clean_title(title):
    """Retire les caractères interdits et les emojis, met en minuscules un titre tout en capitales."""
    title = FORBIDDEN_RE.sub(" ", title)
    title = "".join(c for c in title if unicodedata.category(c) not in ("So", "Cc", "Cf", "Cs", "Co"))
    title = re.sub(r"\s+", " ", title).strip(" -–—:")
    letters = [c for c in title if c.isalpha()]
    if letters and all(c.isupper() for c in letters):
        title = title.lower()
    return title[:1].upper() + title[1:]


def pick_subtitles(info, lang):
    """Choisit la meilleure piste : sous-titres manuels, puis automatiques en langue d'origine."""
    manual = info.get("subtitles") or {}
    auto = info.get("automatic_captions") or {}
    for code in (lang, f"{lang}-FR", f"{lang}-orig"):
        if code in manual:
            return code, "manuelle"
    for code in sorted(manual):
        if code.split("-")[0] == lang:
            return code, "manuelle"
    for code in (f"{lang}-orig", lang):
        if code in auto:
            return code, "automatique"
    return None, None


def vtt_lines(path):
    """Lignes (début en secondes, texte) d'un fichier VTT, sans les répétitions des sous-titres défilants."""
    lines, previous, start = [], None, 0
    for raw in path.read_text(encoding="utf-8").splitlines():
        timing = TIMING_RE.match(raw)
        if timing:
            h, m, s = (int(x) for x in timing.groups())
            start = h * 3600 + m * 60 + s
            continue
        if not raw.strip() or raw.startswith(("WEBVTT", "Kind:", "Language:", "NOTE")):
            continue
        line = re.sub(r"\s+", " ", TAG_RE.sub("", raw)).strip()
        if line and line != previous:
            lines.append((start, line))
            previous = line
    return lines


def by_chapter(lines, chapters):
    """Texte découpé par chapitre, chaque partie précédée de son titre et de son horodatage."""
    parts = []
    for i, chapter in enumerate(chapters):
        end = chapters[i + 1]["debut"] if i + 1 < len(chapters) else float("inf")
        text = " ".join(t for start, t in lines if chapter["debut"] <= start < end)
        h, rest = divmod(int(chapter["debut"]), 3600)
        parts.append(f"### {h}:{rest // 60:02d}:{rest % 60:02d} {chapter['titre']}\n{text}")
    return "\n\n".join(parts)


def to_jpeg(source, target):
    # Sous Windows, « convert » est un outil système sans rapport avec ImageMagick
    tool = shutil.which("magick") or (sys.platform != "win32" and shutil.which("convert"))
    if not tool:
        return False
    result = subprocess.run([tool, str(source), "-strip", "-quality", "90", str(target)], capture_output=True)
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("video", help="URL ou identifiant de la vidéo YouTube")
    parser.add_argument("--lang", help="langue de la transcription (défaut : langue de la vidéo, sinon fr)")
    parser.add_argument("--out", help="dossier de sortie (défaut : tp-travail/youtube-<id>)")
    parser.add_argument("--wiki", default="https://wiki.tripleperformance.fr", help="wiki à vérifier")
    parser.add_argument("--force", action="store_true", help="continue même si la vidéo est déjà sur le wiki")
    args = parser.parse_args()

    vid = video_id(args.video)
    pages = existing_pages(args.wiki, vid)
    if pages and not args.force:
        print(json.dumps({"id": vid, "deja_sur_le_wiki": pages}, ensure_ascii=False, indent=2))
        print("La vidéo est déjà sur le wiki : rien n'a été téléchargé (--force pour continuer).", file=sys.stderr)
        sys.exit(3)
    url = f"https://www.youtube.com/watch?v={vid}"
    out = Path(args.out or f"tp-travail/youtube-{vid}")
    out.mkdir(parents=True, exist_ok=True)

    info = json.loads(run_ytdlp(["--dump-single-json", "--skip-download", url]))
    info_path = out / "info.json"
    info_path.write_text(json.dumps(info, ensure_ascii=False, indent=1), encoding="utf-8")

    lang = args.lang or (info.get("language") or "fr").split("-")[0]
    sub_code, sub_kind = pick_subtitles(info, lang)

    download = ["--load-info-json", str(info_path), "--skip-download", "--write-thumbnail",
                "-o", str(out / "source.%(ext)s")]
    if sub_code:
        download += ["--write-subs" if sub_kind == "manuelle" else "--write-auto-subs",
                     "--sub-langs", sub_code, "--sub-format", "vtt"]
    run_ytdlp(download)

    chapters = [{"debut": c.get("start_time") or 0, "titre": c.get("title") or ""}
                for c in info.get("chapters") or []]
    chapters = [c for c in chapters if not c["titre"].startswith("<Untitled")] or chapters
    if chapters:
        chapters[0]["debut"] = 0

    transcription = ""
    vtt = next(out.glob("source.*.vtt"), None)
    if vtt:
        lines = vtt_lines(vtt)
        transcription = " ".join(t for _, t in lines)
        (out / "transcription.txt").write_text(transcription + "\n", encoding="utf-8")
        if chapters:
            (out / "transcription-chapitres.txt").write_text(by_chapter(lines, chapters) + "\n", encoding="utf-8")

    thumbnail = f"thumbnail_youtube_{vid}.jpg"
    source_thumb = next((p for p in out.glob("source.*") if p.suffix.lower() in (".jpg", ".jpeg", ".webp", ".png")), None)
    thumb_ok = bool(source_thumb) and to_jpeg(source_thumb, out / thumbnail)

    description = info.get("description") or ""
    (out / "description.txt").write_text(description + "\n", encoding="utf-8")

    upload = info.get("upload_date") or ""
    fields = {
        "id": vid,
        "url": url,
        "titre_original": info.get("title", ""),
        "titre_page": clean_title(info.get("title", "")),
        "producteur": info.get("channel") or info.get("uploader") or "",
        "date": f"{upload[:4]}-{upload[4:6]}-{upload[6:]}" if len(upload) == 8 else "",
        "duree": f"{round((info.get('duration') or 0) / 60)} minutes",
        "vignette": thumbnail if thumb_ok else None,
        "transcription": f"{sub_code} ({sub_kind}), {len(transcription.split())} mots" if transcription else None,
        "chapitres": chapters,
        "licence": info.get("license"),
        "deja_sur_le_wiki": pages,
        "dossier": str(out),
    }
    (out / "video.json").write_text(json.dumps(fields, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(fields, ensure_ascii=False, indent=2))

    if not thumb_ok:
        print(f"Attention : vignette non convertie ({source_thumb or 'non téléchargée'}).", file=sys.stderr)
    if not transcription:
        print(f"Attention : aucune transcription disponible en « {lang} ».", file=sys.stderr)


if __name__ == "__main__":
    main()
