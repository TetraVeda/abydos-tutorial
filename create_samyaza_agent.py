from time import sleep

import requests
from keri import kering
from keri.core import coring
from keri.core.coring import Tiers
from signify.app.clienting import SignifyClient
from signify.app.credentialing import CredentialTypes, Registries

wan_prefix = "BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"
wil_prefix = "BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM"
wes_prefix = "BIKKuvBwpmDVA4Ds-EpL5bt9OqPzWPja2LigFYZN2YfX"
def keria_workflow(passcode):
    samyaza_aid_alias = "samyaza"
    samyaza_aid_salt = "0ACn5AEmrsKQJhYxgsp0JGGW"
    boot_url = "http://127.0.0.1:3903/boot"
    agent_url = "http://127.0.0.1:3901"
    tier = Tiers.low

    client = SignifyClient(passcode=passcode, tier=tier)
    print(f'Pilot controller prefix: {client.controller}')

    create_agent(client, boot_url)

    client.connect(url=agent_url)

    identifiers = client.identifiers()
    operations = client.operations()
    oobis = client.oobis()

    # Adds endpoint role of Agent, the default

    make_introductions(oobis, operations)

    samyaza_aid = create_first_aid(samyaza_aid_alias, samyaza_aid_salt, identifiers, operations)
    res = identifiers.addEndRole(samyaza_aid_alias, eid=client.agent.pre)

    # create_registry(client, operations, samyaza_aid, samyaza_aid_alias)

    credentials = client.credentials(aid=samyaza_aid["prefix"])
    creds = credentials.list(typ=CredentialTypes.received)

    print(res)




def create_agent(client, boot_url):
    inception_event, siger = client.ctrl.event()
    inception_json = dict(
        icp=inception_event.ked,
        sig=siger.qb64,
        stem=client.ctrl.stem,
        pidx=1,
        tier=client.ctrl.tier
    )

    res = requests.post(url=boot_url,
                        json=inception_json)
    match res.status_code:
        case 208:
            print('Agent already exists')
        case 400:
            print('Agent already exists')
        case 202:
            print('Agent created')
        case _:
            raise kering.AuthNError(f"Unable to initialize agent: {res.status_code} | {res.text}")
    print(f'Pilot prefix created')
    return res


def create_first_aid(samyaza_aid_alias, samyaza_aid_salt, identifiers, operations):
    # wan, wil, and wes, initialized by the config file
    wits = [
        wan_prefix,
        wil_prefix,
        wes_prefix
    ]

    aids = identifiers.list()
    aid_names = [aid["name"] for aid in aids]
    if 'samyaza' not in aid_names:
        op = identifiers.create(samyaza_aid_alias, bran=samyaza_aid_salt, wits=wits, toad="2")
        while not op["done"]:
            op = operations.get(op["name"])
            sleep(0.1)

        icp = coring.Serder(ked=op["response"])
        print(f'pilot AID {icp.pre} created')

    return identifiers.get("samyaza")


def make_introductions(oobis, operations):
    # Introductions
    explorer_prefix = 'EJS0-vv_OPAQCdJLmkd5dT0EW-mOfhn_Cje4yzRjTv8q'
    explorer_alias = 'richard'
    librarian_prefix = 'EDRVwkL_Y1iGyOqOFUTc1j8msCxyqvlyToTRdjVdLsOi'
    librarian_alias = 'elayne'
    wiseman_prefix = 'EIaJ5gpHSL9nl1XIWDkfMth1uxbD-AfLkqdiZL6S7HkZ'
    wiseman_alias = 'ramiel'
    wan_prefix = 'BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha'

    print(f'Introduce Samyaza to Explorer')
    op = oobis.resolve(oobi=f'http://127.0.0.1:5642/oobi/{explorer_prefix}/witness/{wan_prefix}',
                       alias=explorer_alias)
    while not op["done"]:
        op = operations.get(op["name"])
        sleep(0.1)

    print(f'Introduce Samyaza to Librarian')
    op = oobis.resolve(oobi=f'http://127.0.0.1:5642/oobi/{librarian_prefix}/witness/{wan_prefix}',
                       alias=librarian_alias)
    while not op["done"]:
        op = operations.get(op["name"])
        sleep(0.1)

    print(f'Introduce Samyaza to Wiseman')
    op = oobis.resolve(oobi=f'http://127.0.0.1:5642/oobi/{wiseman_prefix}/witness/{wan_prefix}',
                       alias=wiseman_alias)
    while not op["done"]:
        op = operations.get(op["name"])
        sleep(0.1)

    print(f'Introduce TreasureHuntingJourney credential schema to Samyaza')
    treasure_hunting_journey_schema='EIxAox3KEhiQ_yCwXWeriQ3ruPWbgK94NDDkHAZCuP9l'
    op = oobis.resolve(oobi=f'http://127.0.0.1:7723/oobi/{treasure_hunting_journey_schema}')
    while not op["done"]:
        op = operations.get(op["name"])
        sleep(0.1)
    print(f'Introductions completed')

def create_registry(client, operations, samyaza_aid, samyaza_alias):
    registries: Registries = client.registries()
    op = registries.registryIncept(pre=samyaza_aid["prefix"],
                                   alias=samyaza_alias,
                                   name="samyaza_registry",
                                   body={
                                       "baks": [wan_prefix,
                                                wil_prefix],
                                       "toad": 2
                                   })
    while not op["done"]:
        op = operations.get(op["name"])
        sleep(0.1)
    return op
if __name__ == "__main__":
    passcode = '0AAJwa8OMv3dt9Zwsooq5sSk'
    keria_workflow(passcode)
