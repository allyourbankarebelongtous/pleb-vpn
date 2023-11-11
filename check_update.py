import requests
import markdown

def get_latest_version():
    url = "https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases/latest"
    response = requests.get(url)
    if response.status_code == 200:
        data = response.json()
        latest_version = data.get("tag_name")
        changelog = data.get("body")
        if latest_version:
            html_changelog = convert_markdown_to_html(changelog)
            return latest_version, html_changelog
        else:
            return None, None
    else:
        return None, None

def convert_markdown_to_html(markdown_text):
    html = markdown.markdown(markdown_text)
    return html

latest_version, changelog = get_latest_version()

if latest_version:
    print("Latest Version:", latest_version)
    print("Changelog:\n", changelog)
else:
    print("Failed to retrieve the latest version and changelog.")