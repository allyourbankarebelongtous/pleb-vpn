import requests
from datetime import datetime

# check date of last commit to https://github.com/allyourbankarebelongtous/pleb-vpn/
def check_repository_updated(branch=""):
    url = f"https://api.github.com/repos/allyourbankarebelongtous/pleb-vpn/commits/{branch}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()

        if data:  # Check if data is not empty
            last_commit_date = data["commit"]["committer"]["date"]
            dt = datetime.strptime(last_commit_date, "%Y-%m-%dT%H:%M:%SZ")
            formatted_date = dt.strftime("%Y-%m-%d %H:%M:%S %z")
            print(formatted_date)
            return formatted_date
        else:
            print("no data")
            return None
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        return None
    
check_repository_updated('mynode') # branch included for testing purposes