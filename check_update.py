import requests
import re
import markdown

def get_latest_version():
    url = "https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases"
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        versions = [release["tag_name"] for release in data]
        sorted_versions = sorted(versions, key=version_key, reverse=True)
        latest_version = sorted_versions[0] if sorted_versions else None
        
        # Retrieve changelog if a latest version is found
        if latest_version:
            changelog = get_changelog(latest_version)
            return latest_version, changelog
        else:
            return None
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

def get_changelog(version):
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases/tags/{version}"
    response = requests.get(url)
    
    if response.status_code == 200:
        data = response.json()
        changelog = data.get("body")
        return changelog
    else:
        return None

def convert_markdown_to_html(markdown_text):
    html = markdown.markdown(markdown_text)
    return html

latest_version, changelog = get_latest_version()

if latest_version:
    print("Latest Version:", latest_version)
    html_changelog = convert_markdown_to_html(changelog)
    print("Changelog:\n", html_changelog)
else:
    print("Failed to retrieve the latest version and changelog.")

