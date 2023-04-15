#!/bin/bash

echo "Press ENTER to continue"
read key </dev/tty
echo "Success!"
echo "now enter your name"
read -p "Enter fullname: " fullname
echo "Your name is: ${fullname}"
echo "Success!"
echo "this rocks! Let's now have you put in your SSN!"
read -p "Enter all of your personal data, beginning with your SSN: " lol
echo "muahaha"
echo "Your SSN is: ${lol}"
echo "have fun staying poor!"
echo "better get a credit check"
exit 0

