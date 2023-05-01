from datetime import datetime, timedelta

today = datetime.now()
yesterday = datetime.now() - timedelta(days=1)
sunday = today - timedelta(days=today.weekday())
saturday = sunday - timedelta(days=1)
first_of_month = datetime(today.year, today.month, 1)
last_of_month = first_of_month - timedelta(days=1)
first_of_year = datetime(today.year, 1, 1)
last_of_year = first_of_year - timedelta(days=1)
today = datetime(today.year, today.month, today.day, 1, 0, 0)
yesterday = datetime(yesterday.year, yesterday.month, yesterday.day, 23, 0, 0)
sunday = datetime(sunday.year, sunday.month, sunday.day, 1, 0, 0)
saturday = datetime(saturday.year, saturday.month, saturday.day, 23, 0, 0)
first_of_month = datetime(first_of_month.year, first_of_month.month, first_of_month.day, 1, 0, 0)
last_of_month = datetime(last_of_month.year, last_of_month.month, last_of_month.day, 23, 0, 0)
first_of_year = datetime(first_of_year.year, first_of_year.month, first_of_year.day, 1, 0, 0)
last_of_year = datetime(last_of_year.year, last_of_year.month, last_of_year.day, 23, 0, 0)
today = today.strftime("%Y-%m-%d %H:%M:%S")
yesterday = yesterday.strftime("%Y-%m-%d %H:%M:%S")
sunday = sunday.strftime("%Y-%m-%d %H:%M:%S")
saturday = saturday.strftime("%Y-%m-%d %H:%M:%S")
first_of_month = first_of_month.strftime("%Y-%m-%d %H:%M:%S")
last_of_month = last_of_month.strftime("%Y-%m-%d %H:%M:%S")
first_of_year = first_of_year.strftime("%Y-%m-%d %H:%M:%S")
last_of_year = last_of_year.strftime("%Y-%m-%d %H:%M:%S")

start_date = "start=$(date -d '" + yesterday + "' +%s); "
end_date = "end=$(date -d '" + today + "' +%s); "



jq_str = r'.payments[] | select(.creation_date > "${start}" and .creation_date < "${end}") | {creation_date, value_sat, status}'


cmd_str = ['start=$(date -d \'' + yesterday + '\' +%s); end=$(date -d \'' + today + '\' +%s); lncli listpayments | jq \".payments[] | select(.creation_date > \\"${start}\\" and .creation_date < \\"${end}\\") | {creation_date, value_sat, status}\"']


print(cmd_str)