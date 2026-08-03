#!/usr/bin/env python3
"""手动下载 Flutter pub 依赖 - 使用 wget"""
import os, json, subprocess, hashlib

FLUTTER_HOME = os.environ.get('FLUTTER_HOME', '/vol1/@apphome/trim.openclaw/data/home/sdk/flutter_sdk')
PUB_CACHE = os.environ.get('PUB_CACHE', os.path.expanduser('~/.pub-cache'))
HOSTED = os.path.join(PUB_CACHE, 'hosted', 'pub.dartlang.org')
PUBSPEC = os.path.dirname(__file__)

os.makedirs(HOSTED, exist_ok=True)

def wget(url, output, timeout=30):
    """用wget下载文件，忽略证书错误"""
    cmd = ['wget', '-q', '--no-check-certificate', '-O', output, url]
    try:
        r = subprocess.run(cmd, timeout=timeout)
        return r.returncode == 0
    except subprocess.TimeoutExpired:
        return False

def get_package_versions(name):
    """从 pub.dev API 获取版本列表"""
    url = f'https://pub.dev/api/packages/{name}'
    out = f'/tmp/pkg_{name}.json'
    if wget(url, out):
        with open(out) as f:
            return json.load(f)
    return None

def download_package(name, version):
    """下载并缓存单个包"""
    cache_file = os.path.join(HOSTED, f'{name}-{version}.tar.gz')
    if os.path.exists(cache_file):
        print(f'  ✓ 已缓存 {name}@{version}')
        return True

    print(f'  ↓ 下载 {name}@{version}...')
    url = f'https://pub.dev/packages/{name}/versions/{version}/tar'
    if wget(url, cache_file):
        print(f'  ✓ {name}@{version}')
        return True
    else:
        print(f'  ✗ 下载失败 {name}@{version}')
        return False

def get_latest(name):
    """获取最新版本号"""
    data = get_package_versions(name)
    if data:
        return data['latest']['version']
    return None

def parse_pubspec():
    """解析pubspec.yaml"""
    deps = {}
    path = os.path.join(PUBSPEC, 'pubspec.yaml')
    with open(path) as f:
        content = f.read()

    in_deps = False
    for line in content.split('\n'):
        if 'dependencies:' in line:
            in_deps = True
            continue
        if any(x in line for x in ['dev_dependencies:', 'dependency_overrides:']):
            in_deps = False
            continue
        if not line.strip() or line.strip().startswith('#'):
            continue
        if line.startswith('  ') and in_deps:
            parts = line.strip().split(':')
            if len(parts) >= 1:
                name = parts[0].strip()
                if name in ('flutter', 'flutter_test', 'flutter_driver'): continue
                version = 'any'
                if len(parts) >= 2:
                    ver = parts[1].strip()
                    if ver.startswith('^'):
                        version = ver[1:]
                    elif ver not in ('any', 'sdk') and not ver.startswith('sdk:'):
                        version = ver
                deps[name] = version
        elif not line.startswith(' '):
            in_deps = False
    return deps

def main():
    print(f'Flutter: {FLUTTER_HOME}')
    print(f'缓存:   {HOSTED}')
    print()

    deps = parse_pubspec()
    # 加上已知的版本
    known = {
        'flutter_lints': '4.0.0',
        'flutter_riverpod': '2.5.1',
        'http': '1.2.0',
        'shared_preferences': '2.2.2',
        'fl_chart': '0.68.0',
        'go_router': '14.2.0',
        'intl': '0.19.0',
        'flutter_localizations': '0.0.0',  # flutter sdk内置
    }
    deps.update(known)
    deps.pop('flutter', None)

    print(f'共 {len(deps)} 个依赖')
    print()

    success, failed = 0, []
    for name, version in deps.items():
        print(f'{name}@{version}:')
        if version == 'any':
            version = get_latest(name)
            if not version:
                print(f'  ✗ 获取版本失败')
                failed.append(name)
                continue
        if download_package(name, version):
            success += 1
        else:
            failed.append(name)

    print()
    print(f'完成: {success} 成功, {len(failed)} 失败')
    if failed: print(f'失败: {failed}')

if __name__ == '__main__':
    main()
