#!/usr/bin/env python3
"""Gera docs/preview.svg com o visual real do claude-monitor."""

import re, html, os

PALETTE = {
    45:  '#00d7ff',
    75:  '#5fafff',
    82:  '#5fd700',
    171: '#d75fff',
    196: '#ff5f5f',
    220: '#ffd75f',
    244: '#808080',
}

def parse_ansi(text):
    segments = []
    current_color = '#c0c0c0'
    parts = re.split(r'\x1b\[([^m]*)m', text)
    for i, part in enumerate(parts):
        if i % 2 == 0:
            if part:
                segments.append((current_color, part))
        else:
            codes = [int(c) for c in part.split(';') if c.isdigit()]
            if not codes or codes == [0]:
                current_color = '#c0c0c0'
            elif len(codes) == 3 and codes[0] == 38 and codes[1] == 5:
                current_color = PALETTE.get(codes[2], '#c0c0c0')
    return segments

def make_tspans(segments):
    spans = []
    for color, text in segments:
        escaped = html.escape(text)
        spans.append(f'<tspan fill="{color}">{escaped}</tspan>')
    return ''.join(spans)

# Monta os dados de exemplo com ANSI diretamente (não depende de bash)
E = '\x1b'
R   = f'{E}[0m'
CYN = f'{E}[38;5;45m'
GRY = f'{E}[38;5;244m'
BLU = f'{E}[38;5;75m'
YEL = f'{E}[38;5;220m'
MAG = f'{E}[38;5;171m'
GRN = f'{E}[38;5;82m'
S   = f'{GRY} │ {R}'

# Linha 1: modelo, dir, branch, agente ativo, skill ativa
line1 = (
    f'{CYN}[Sonnet 4.6]{R}{S}'
    f'{BLU}📁 my-project{R}{S}'
    f'{YEL}🐱 feature/auth{R}{S}'
    f'{MAG}🤖 @dev{R}{S}'
    f'{MAG}⚡ /tlc-spec-driven{R}'
)

# Linha 2: contexto 35% (verde), compact 2x (amarelo), limite 68% (amarelo)
line2 = (
    f'   {GRY}contexto{R} {GRN}███░░░░░░░ 35%{R}{S}'
    f'{YEL}compact: 2x{R}{S}'
    f'{GRY}limite de uso{R}  {YEL}██████░░░░ 68%{R}{GRY} ↻ 1h23m{R}'
)

seg1 = parse_ansi(line1)
seg2 = parse_ansi(line2)

tspan1 = make_tspans(seg1)
tspan2 = make_tspans(seg2)

W, H = 860, 80
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" role="img" aria-label="claude-monitor preview">
  <rect width="{W}" height="{H}" rx="8" fill="#1a1a1a"/>
  <text x="16" y="30" font-family="'Cascadia Code','Fira Code','Consolas','Courier New',monospace" font-size="13">{tspan1}</text>
  <text x="16" y="56" font-family="'Cascadia Code','Fira Code','Consolas','Courier New',monospace" font-size="13">{tspan2}</text>
</svg>'''

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview.svg')
with open(out, 'w', encoding='utf-8') as f:
    f.write(svg)
print(f"Gerado: {out}")
