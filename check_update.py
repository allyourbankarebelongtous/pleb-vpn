import requests
import re

def get_latest_version():
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases"
    response = requests.get(url)
    if response.status_code == 200:
        data = response.json()
        versions = [release["tag_name"] for release in data]
        sorted_versions = sorted(versions, key=version_key, reverse=True)
        latest_version = sorted_versions[0] if sorted_versions else None
        return latest_version
    else:
        return None

def version_key(version):
    match = re.search(r'v(\d+)\.(\d+)', version)
    if match:
        major = int(match.group(1))
        minor = int(match.group(2))
        return major, minor, version
    else:
        return float('inf'), version

version = get_latest_version()
print(version)