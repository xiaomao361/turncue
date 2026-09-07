#!/usr/bin/env python3
"""Check the static site's local references and essential page metadata."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1] / 'docs'
BASE = 'https://xiaomao361.github.io/turncue/'
PAGES = ['index.html', 'guide/index.html', 'privacy/index.html',
         'support/index.html', 'changelog/index.html']

class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.refs, self.ids, self.errors = [], set(), []
        self.headings = 0
        self.tags, self.meta, self.rels = {}, {}, {}
        self.has_title = False
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.setdefault(tag, []).append(attrs)
        if tag == 'title':
            self.in_title = True
        if tag == 'h1':
            self.headings += 1
        if 'id' in attrs:
            if attrs['id'] in self.ids:
                self.errors.append(f'duplicate id: {attrs["id"]}')
            self.ids.add(attrs['id'])
        if tag == 'meta':
            self.meta[attrs.get('name', attrs.get('property'))] = attrs.get('content')
        if tag == 'link':
            self.rels[attrs.get('rel')] = attrs.get('href')
        if tag == 'img' and not attrs.get('alt'):
            self.errors.append('image missing descriptive alt')
        for key in ('href', 'src'):
            if key in attrs:
                self.refs.append(attrs[key])

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False

    def handle_data(self, data):
        if self.in_title and data.strip():
            self.has_title = True


def main():
    errors, parsed = [], {}
    for name in PAGES:
        path = ROOT / name
        doc = Page()
        doc.feed(path.read_text())
        parsed[path] = doc
        checks = {
            'one h1': doc.headings == 1,
            'title': doc.has_title,
            'Chinese language': doc.tags.get('html', [{}])[0].get('lang') == 'zh-Hans',
            'viewport': bool(doc.meta.get('viewport')),
            'description': bool(doc.meta.get('description')),
            'canonical': doc.rels.get('canonical') == BASE + name.removesuffix('index.html'),
            'social URL': doc.meta.get('og:url') == doc.rels.get('canonical'),
            'social image': doc.meta.get('og:image') == BASE + 'assets/app-icon.png',
            'main target': 'main' in doc.ids,
            'no scripts': 'script' not in doc.tags,
        }
        errors += [f'{name}: missing/invalid {key}' for key, passed in checks.items() if not passed]
        errors += [f'{name}: {message}' for message in doc.errors]
    count = 0
    for path, doc in parsed.items():
        for raw in doc.refs:
            ref = urlsplit(raw)
            if ref.scheme or ref.netloc:
                continue
            target = (path.parent / unquote(ref.path)).resolve() if ref.path else path
            if target.is_dir():
                target /= 'index.html'
            count += 1
            if not target.is_relative_to(ROOT) or not target.is_file():
                errors.append(f'{path.relative_to(ROOT)}: broken local reference {raw}')
            elif ref.fragment and (target not in parsed or unquote(ref.fragment) not in parsed[target].ids):
                errors.append(f'{path.relative_to(ROOT)}: missing anchor {raw}')
    sitemap = ET.parse(ROOT / 'sitemap.xml')
    urls = [item.text for item in sitemap.findall('.//{http://www.sitemaps.org/schemas/sitemap/0.9}loc')]
    expected = [BASE + name.removesuffix('index.html') for name in PAGES]
    if sorted(urls) != sorted(expected):
        errors.append('sitemap does not match public pages')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'PASS: {len(parsed)} pages, {count} local references, metadata and sitemap')

if __name__ == '__main__':
    main()
