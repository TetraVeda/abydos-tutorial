from time import sleep

import requests
from keri import kering
from keri.core import coring
from keri.core.coring import Tiers
from signify.app.clienting import SignifyClient


def resolve_oobis(passcode):
    samyaza_aid_alias = "samyaza"
    boot_url = "http://127.0.0.1:3903/boot"
    agent_url = "http://127.0.0.1:3901"
    tier = Tiers.low

    client = SignifyClient(passcode=passcode, tier=tier)
    print(f'Pilot prefix: {client.controller}')

    client.connect(url=agent_url)
    oobis = client.oobis()
    # op = oobis.resolve(oobi=f'{explorer_prefix}/witness/{wan_prefix}',
    #                    alias=explorer_alias)

if __name__ == "__main__":
    passcode = '0AAJwa8OMv3dt9Zwsooq5sSk'
    resolve_oobis(passcode)