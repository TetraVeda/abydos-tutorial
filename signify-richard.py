import json
import os
from time import sleep

import requests
from keri.app.keeping import Algos
from keri.core import coring
import responses
from responses import _recorder

import pytest
from keri import kering
from keri.core.coring import Tiers, Serder, MtrDex

from signify.app.clienting import SignifyClient

@responses.activate
def read_responses():
    SIGNIFY_TEST_DIR='/Users/kbull/code/keri/kentbull/signifypy/tests/app'
    responses._add_from_file(file_path=os.path.join(SIGNIFY_TEST_DIR, 'connect.toml'))


def main():
    read_responses()
    admin_url = "http://localhost:3901"
    bootstrap_url = "http://localhost:3903/boot"
    # bran = passcode for the db and keystore (habery)
    passcode = b'0123456789abcdefghijk'
    aid2_bran="0123456789lmnopqrstuv"
    # tier (str low|med|high): value from Tierage for security level of stretch
    tier = None

    client = SignifyClient(passcode=passcode, tier=tier)
    # Your client public key - Richard
    assert client.controller == "ELI7pg979AdhmvrjDeam2eAO2SR5niCgnjAJXJHtJose"
    # Get the inception event
    serder = client.icp
    inception_event = json.loads(serder.raw)
    # Review the inception event
    assert serder.raw == (b'{"v":"KERI10JSON00012b_","t":"icp","d":"ELI7pg979AdhmvrjDeam2eAO2SR5niCgnjAJ'
                          b'XJHtJose","i":"ELI7pg979AdhmvrjDeam2eAO2SR5niCgnjAJXJHtJose","s":"0","kt":"1'
                          b'","k":["DAbWjobbaLqRB94KiAutAHb_qzPpOHm3LURA_ksxetVc"],"nt":"1","n":["EIFG_u'
                          b'qfr1yN560LoHYHfvPAhxQ5sN6xZZT_E3h7d2tL"],"bt":"0","b":[],"c":[],"a":[]}')
    print(f"Inception event is: {inception_event['i']}")

    # Post inception event to KERIA boot interface, out of band with respect to the Signify Client to KERIA connection
    evt, siger = client.ctrl.event()
    inception_event_request = dict(
        icp=evt.ked,
        sig=siger.qb64,
        stem=client.ctrl.stem,
        pidx=1,
        tier=client.ctrl.tier
    )
    res = requests.post(url=bootstrap_url,
                        json=inception_event_request)
    if res.status_code != requests.codes.accepted:
        raise kering.AuthNError(f"Unable to initialize KERIA agent connection: {res.status_code} - {res.text}")

    client.connect(url=admin_url)
    assert client.agent is not None
    assert client.agent.delpre == "ELI7pg979AdhmvrjDeam2eAO2SR5niCgnjAJXJHtJose"
    assert client.agent.pre == "EEXekkGu9IAzav6pZVJhkLnjtjM5v3AcyA-pdKUcaGei"
    assert client.agent.sn == 0

    identifiers = client.identifiers()
    aids = identifiers.list()
    assert aids == []

    events = client.keyEvents()

    aid1, icp1 = create_first_aid(identifiers, passcode)
    _aid2, _icp2 = create_second_aid(identifiers, aid2_bran)
    rot1 = rotate_first_aid(identifiers)
    ixn1 = create_first_interaction_event(identifiers, icp1, rot1)
    review_key_events_and_list_identifiers(events, identifiers, aid1, icp1, rot1, ixn1)

def create_first_aid(identifiers, passcode):
    aid = identifiers.create("aid1", bran=passcode.decode('utf-8'))
    icp = Serder(ked=aid)
    assert "ELUvZ8aJEHAQE-0nsevyYTP98rBbGJUrTj5an-pCmwrK" == icp.pre
    assert len(icp.verfers) == 1
    assert icp.verfers[0].qb64 == "DPmhSfdhCPxr3EqjxzEtF8TVy0YX7ATo0Uc8oo2cnmY9"
    assert len(icp.digers) == 1
    assert icp.digers[0].qb64 == "EAORnRtObOgNiOlMolji-KijC_isa3lRDpHCsol79cOc"
    assert icp.tholder.num == 1
    assert icp.ntholder.num == 1

    rpy = identifiers.makeEndRole(pre=icp.pre, eid='EPGaq6inGxOx-VVVEcUb_KstzJZldHJvVsHqD4IPxTWf')
    assert rpy.ked['a']['cid'] == "ELUvZ8aJEHAQE-0nsevyYTP98rBbGJUrTj5an-pCmwrK"
    assert rpy.ked['a']['eid'] == "EPGaq6inGxOx-VVVEcUb_KstzJZldHJvVsHqD4IPxTWf"

    aids = identifiers.list()
    assert len(aids) == 1
    aid = aids.pop()

    salt = aid[Algos.salty]
    assert aid['name'] == "aid1"
    assert salt['pidx'] == 0
    assert aid['prefix'] == icp.pre
    assert salt['stem'] == "signify:aid"
    return aid, icp

def create_second_aid(identifiers, passcode):
    aid2 = identifiers.create("aid2", count=3, ncount=3, isith='2', nsith='2', bran=passcode)
    icp2 = Serder(ked=aid2)
    assert icp2.pre == "EP10ooRj0DJF0HWZePEYMLPl-arMV-MAoTKK-o3DXbgX"
    assert len(icp2.verfers) == 3
    assert icp2.verfers[0].qb64 == "DGBw7C7AfC7jbD3jLLRS3SzIWFndM947TyNWKQ52iQx5"
    assert icp2.verfers[1].qb64 == "DD_bHYFsgWXuCbz3SD0HjCIe_ITjRvEoCGuZ4PcNFFDz"
    assert icp2.verfers[2].qb64 == "DEe9u8k0fm1wMFAuOIsCtCNrpduoaV5R21rAcJl0awze"
    assert len(icp2.digers) == 3
    assert icp2.digers[0].qb64 == "EML5FrjCpz8SEl4dh0U15l8bMRhV_O5iDcR1opLJGBSH"
    assert icp2.digers[1].qb64 == "EJpKquuibYTqpwMDqEFAFs0gwq0PASAHZ_iDmSF3I2Vg"
    assert icp2.digers[2].qb64 == "ELplTAiEKdobFhlf-dh1vUb2iVDW0dYOSzs1dR7fQo60"
    assert icp2.tholder.num == 2
    assert icp2.ntholder.num == 2

    aids = identifiers.list()
    assert len(aids) == 2
    aid = aids[1]
    assert aid['name'] == "aid2"
    assert aid["prefix"] == icp2.pre
    salt = aid[Algos.salty]
    assert salt["pidx"] == 1
    assert salt["stem"] == "signify:aid"
    return aid, icp2

def rotate_first_aid(identifiers):
    ked = identifiers.rotate("aid1")
    rot = Serder(ked=ked)

    assert rot.said == "EBQABdRgaxJONrSLcgrdtbASflkvLxJkiDO0H-XmuhGg"
    assert rot.sn == 1
    assert len(rot.digers) == 1
    assert rot.verfers[0].qb64 == "DHgomzINlGJHr-XP3sv2ZcR9QsIEYS3LJhs4KRaZYKly"
    assert rot.digers[0].qb64 == "EJMovBlrBuD6BVeUsGSxLjczbLEbZU9YnTSud9K4nVzk"
    return rot

def create_first_interaction_event(identifiers, icp, rot):
    ked = identifiers.interact("aid1", data=[icp.pre])
    ixn = Serder(ked=ked)
    assert ixn.said == "ENsmRAg_oM7Hl1S-GTRMA7s4y760lQMjzl0aqOQ2iTce"
    assert ixn.sn == 2
    assert ixn.ked["a"] == [icp.pre]

    aid = identifiers.get("aid1")
    state = aid["state"]
    assert state['s'] == '2'
    assert state['f'] == '2'
    assert state['et'] == 'ixn'
    assert state['d'] == ixn.said
    assert state['ee']['d'] == rot.said
    return ixn

def review_key_events_and_list_identifiers(events, identifiers, aid, icp, rot, ixn):
    log = events.get(pre=aid["prefix"])
    assert len(log) == 3
    serder = coring.Serder(ked=log[0])
    assert serder.pre == icp.pre
    assert serder.said == icp.said
    serder = coring.Serder(ked=log[1])
    assert serder.pre == rot.pre
    assert serder.said == rot.said
    serder = coring.Serder(ked=log[2])
    assert serder.pre == ixn.pre
    assert serder.said == ixn.said

    print(identifiers.list())

main()