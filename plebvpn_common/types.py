import json
from enum import IntEnum
from pydantic import BaseModel
from typing import Union


class PlebError(IntEnum):
    SUCCESS = 0
    UNKNOWN = 1
    BAD_PORT = 2
    NO_CONNECTION = 3
    ACCOUNT_DOES_NOT_EXIST = 4
    ACCOUNT_ALREADY_EXISTS = 5
    INVALID_CREDENTIALS = 6


class UserAccountInfo(BaseModel):
    name: Union[str, None] = "satoshi"
    port: Union[int, None] = 80
    ip_addr: Union[str, None] = "0.0.0.0"
    pubkey: Union[str, None] = "default"
    agreed_price: Union[int, None] = 1000
    agreed_denomination: Union[str, None] = "sats"
    ovpn_filename: Union[str, None] = "/etc/openvpn/ovpns/dummy"
    ovpn_bytes: Union[bytes, None] = b'default'
    secret: Union[str, None] = "lolwut"


###### HTTP Request schemas #######
class NewAccountReq(BaseModel):
    port: int
    pubkey: str
    name: str


class PortReq(BaseModel):
    port: int


class OpenVPNReq(BaseModel):
    name: str
    secret: str


class CheckAccountReq(BaseModel):
    name: str
