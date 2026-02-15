#!/usr/bin/env python3
"""
Genera manifiestos KB para ChristianOS a partir de novedades usando la API de ChatGPT.

Requisitos:
  - OPENAI_API_KEY en variables de entorno.
Opcional:
  - OPENAI_MODEL (default: gpt-5-mini)

Ejemplo (una release):
  python src/generate_kb_with_ai.py \
    --novedades "Arregla WiFi, mejora inicio de sesión y parche de seguridad" \
    --product ChristianOS11 \
    --releases 25H2 \
    --kb KB0002

Ejemplo (múltiples releases):
  python src/generate_kb_with_ai.py \
    --novedades "Mejoras de seguridad y estabilidad" \
    --product ChristianOS11 \
    --releases 22H2,24H2,25H2 \
    --kb KB0003
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path


@dataclass
class KBPlan:
    update_name: str
    description: str
    package_type: str  # MSI o CAB
    package_basename: str


def _normalize_release_list(raw_releases: str) -> list[str]:
    releases = [r.strip().upper() for r in raw_releases.split(",") if r.strip()]
    if not releases:
        raise ValueError("Debes indicar al menos una release en --releases")

    pattern = re.compile(r"^\d{2}H\d$")
    invalid = [r for r in releases if not pattern.match(r)]
    if invalid:
        raise ValueError(f"Release(s) inválidas: {', '.join(invalid)}. Usa formato 22H2, 24H2, 25H2...")

    # Eliminar duplicados respetando orden.
    deduped: list[str] = []
    for release in releases:
        if release not in deduped:
            deduped.append(release)
    return deduped


def _post_chat_completions(api_key: str, model: str, novedades: str, product: str, releases: list[str], kb: str) -> KBPlan:
    """Llama a la API de ChatGPT y pide un JSON mínimo para el plan de KB."""

    url = "https://api.openai.com/v1/chat/completions"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }

    system_prompt = (
        "Eres un asistente de release engineering para ChristianOS Update. "
        "Responde únicamente JSON válido."
    )

    user_prompt = (
        "Dadas estas novedades, decide si conviene empaquetar como MSI o CAB para una KB. "
        "Usa CAB para cambios de sistema/parches acumulativos y MSI para componente/aplicación instalable. "
        "Devuelve JSON con claves exactas: update_name, description, package_type, package_basename.\n\n"
        f"Producto: {product}\n"
        f"Releases objetivo: {', '.join(releases)}\n"
        f"KB: {kb}\n"
        f"Novedades: {novedades}\n"
    )

    payload = {
        "model": model,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }

    req = urllib.request.Request(
        url=url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=60) as response:
        raw = response.read().decode("utf-8")

    data = json.loads(raw)
    content = data["choices"][0]["message"]["content"]
    parsed = json.loads(content)

    package_type = str(parsed.get("package_type", "CAB")).upper().strip()
    if package_type not in {"MSI", "CAB"}:
        package_type = "CAB"

    package_basename = re.sub(
        r"[^A-Za-z0-9._-]+",
        "-",
        str(parsed.get("package_basename", f"{kb}-{product}")),
    ).strip("-")
    if not package_basename:
        package_basename = f"{kb}-{product}"

    return KBPlan(
        update_name=str(parsed.get("update_name", f"ChristianOS Update {kb}")),
        description=str(parsed.get("description", "Actualización generada automáticamente")),
        package_type=package_type,
        package_basename=package_basename,
    )


def build_manifest(plan: KBPlan, product: str, release: str, kb: str, author: str) -> dict:
    ext = ".msi" if plan.package_type == "MSI" else ".cab"
    package_name = f"{plan.package_basename}-{release}{ext}"

    return {
        "updateName": f"{plan.update_name} ({release})",
        "version": "1.0.0",
        "type": plan.package_type,
        "sha256": "AUTO_GENERATE",
        "compatibility": {product: [release]},
        "releaseDate": str(date.today()),
        "author": author,
        "description": plan.description,
        "files": [
            {
                "name": package_name,
                "path": f"./packages/{package_name}",
                "size": "AUTO",
                "sha256": "AUTO_GENERATE",
            }
        ],
        "reporting": {
            "logFile": f"./reports/{kb}-{product}-{release}.log",
            "status": "PENDING",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Genera manifiestos KB usando ChatGPT API (MSI o CAB)")
    parser.add_argument("--novedades", required=True, help="Texto de novedades para la KB")
    parser.add_argument("--product", required=True, help="Ej: ChristianOS11")
    parser.add_argument("--releases", required=True, help="Releases destino separadas por coma. Ej: 22H2,24H2,25H2")
    parser.add_argument("--kb", required=True, help="Ej: KB0002")
    parser.add_argument("--author", default="MicroChristian Corporation")
    parser.add_argument(
        "--output-dir",
        default="manifests",
        help="Directorio de salida para manifiestos. Se genera uno por release.",
    )
    args = parser.parse_args()

    try:
        releases = _normalize_release_list(args.releases)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("ERROR: Falta OPENAI_API_KEY en variables de entorno.", file=sys.stderr)
        return 3

    model = os.getenv("OPENAI_MODEL", "gpt-5-mini")

    try:
        plan = _post_chat_completions(
            api_key=api_key,
            model=model,
            novedades=args.novedades,
            product=args.product,
            releases=releases,
            kb=args.kb,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR llamando a la API de ChatGPT: {exc}", file=sys.stderr)
        return 4

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for release in releases:
        manifest = build_manifest(plan, args.product, release, args.kb, args.author)
        out_file = output_dir / f"{args.kb}-{args.product}-{release}.json"
        out_file.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"✅ Manifiesto generado: {out_file}")
        print(f"   Tipo recomendado por IA: {plan.package_type}")
        print(f"   Paquete esperado: {manifest['files'][0]['name']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
