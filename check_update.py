import requests, re

# check latest release version for https://github.com/allyourbankarebelongtous/pleb-vpn/
def get_latest_version():
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/releases"
    response = requests.get(url)
    releases = response.json()

    if response.status_code == 200:
        # Filter and extract versions from the release names
        versions = [
            release["tag_name"]
            for release in releases
            if release["tag_name"].startswith("v")
        ]

        # Custom sorting function
        def custom_sort_key(version):
            version_without_v = re.sub(r"v", "", version)
            version_segments = re.split(r"[.-]", version_without_v)
            version_segments = [
                int(segment) if segment.isdigit() else segment
                for segment in version_segments
            ]
            return version_segments

        # Sort the versions using the custom sort key function
        versions.sort(key=custom_sort_key, reverse=True)

        if versions:
            return versions[0]  # Return the latest version

    return None  # Return None if no versions found or API request failed
    
latestversion = get_latest_version() # if run by bash scripts, check for updates and return latest version
print(latestversion)