import requests
from datetime import datetime

# check latest release version for https://github.com/allyourbankarebelongtous/pleb-vpn/
def get_latest_version():
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases"
    response = requests.get(url)
    releases = response.json()

    if response.status_code == 200:
        # Filter and extract versions from the release names
        versions = [
            release["name"].split("_")[1].split(".tar.gz")[0][1:]
            for release in releases
        ]

        # Sort the versions in descending order
        versions.sort(reverse=True)

        if versions:
            return versions[0]  # Return the latest version

    return None  # Return None if no versions found or API request failed
    
get_latest_version() # for testing purposes