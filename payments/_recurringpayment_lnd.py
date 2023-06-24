#!/usr/bin/python
import requests
import logging
import logging.handlers
import subprocess
import argparse
import sys
from time import sleep

# get an instance of the logger object this module will use
logging.basicConfig(level=logging.DEBUG, format="%(asctime)-15s %(levelname)-8s %(message)s")


def get_price_at(timestamp="now"):
    requests_session = requests.Session()

    currency = "usd"
    if timestamp == "now":
        price = requests_session.get(
            "https://www.bitstamp.net/api/v2/ticker/btc{}".format(currency)
        ).json()["last"]
    else:
        price = requests_session.get(
            "https://www.bitstamp.net/api/v2/ohlc/btc{}/?limit=1&step=86400&start={}".format(
                currency, timestamp
            )
        ).json()["data"]["ohlc"][0]["close"]
    return price


def send_to_node(node, fee_limit, sats, message):
    sats = str(int(sats))
    logging.info("Sending {0} sats to {1}".format(sats, node))
    cmd = ['lncli', 'sendpayment', '--fee_limit', str(fee_limit), '--dest='+node, '--amt='+sats]

    # Add keysend message, if available
    if message is not None:
        cmd.append("--data")
        cmd.append("34349334="+message.encode("utf-8").hex())

    # Add keysend argument
    cmd.append("--keysend")

    # Send payment
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    if p.returncode == 0:
        logging.info("Successfully sent {0} sats".format(sats))
        return True, None, None
    else:
        stdout_message = p.stdout.decode()
        stderr_message = p.stderr.decode()
        logging.info(stdout_message)
        logging.error(stderr_message)
        return False, stdout_message, stderr_message

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Parse some args')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--sats', type=int, help="Sends AMOUNT sats")
    group.add_argument('--usd', type=float, help="Sends AMOUNT dollars (Fractions allowed)")
    parser.add_argument('--fee_limit', type=int, help="Sets maximum routing fee for payment in sats (default = 10)")
    parser.add_argument('--node_id', required=True, help="Node address to send to")
    parser.add_argument('--message', help="Optional, send a message to node")
    parser.add_argument('--send_now', type=bool, help="Send the payment only once and capture the output")

    args = parser.parse_args()

    if args.send_now:
        print("Attempting to send...")
        try:
            # Calculate price in dollars
            if args.usd is not None:
                price = get_price_at()
                args.sats = args.usd * 100000000 / float(price)  # Convert to sats

            # Set default fee of 10 sats if none is present
            if args.fee_limit is None:
                args.fee_limit = 10

            success, stdout_msg, stderr_msg = send_to_node(args.node_id, args.fee_limit, args.sats, args.message)

            # Check result
            if success:
                print("Payment successfully sent!")
            else:
                print("Error occurred. Check the stdout and stderr messages:")
                print("stdout:", stdout_msg)
                print("stderr:", stderr_msg)

        except Exception as e:
            print(e)
            print("Failed to hit bitstamp api")
 
    else:
        for send_attempt in range(0, 10):
            logging.info("Attempting to send.. attempt {0}/{1}".format(send_attempt+1, 10))
            try:
                # Calculate price in dollars
                if args.usd is not None:
                    price = get_price_at()
                    args.sats = args.usd * 100000000 / float(price)  # Convert to sats

                # Set default fee of 10 sats if none is present
                if args.fee_limit is None:
                    args.fee_limit = 10

                success, stdout_msg, stderr_msg = send_to_node(args.node_id, args.fee_limit, args.sats, args.message)
                if success:
                    break

            except Exception as e:
                logging.error(e)
                logging.error("Failed to hit bitstamp api")

            sleep(60 * send_attempt+1)